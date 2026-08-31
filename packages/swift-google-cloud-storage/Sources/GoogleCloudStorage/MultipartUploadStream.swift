// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import NIOCore

/// A thread-safe container to capture errors occurring inside streaming sequences.
final class StreamErrorHolder: @unchecked Sendable {
  var streamError: (any Error)?
}

/// An AsyncSequence that frames an UploadSource with multipart/related boundaries on the fly.
struct MultipartUploadStream<S: UploadSource>: AsyncSequence, Sendable {
  typealias Element = NIOCore.ByteBuffer

  let source: S
  let boundary: String
  let metadataJson: Data
  let contentType: String
  let totalSize: Int64?
  let errorHolder: StreamErrorHolder?
  let chunkSize: Int

  init(
    source: S,
    boundary: String,
    metadataJson: Data,
    contentType: String,
    totalSize: Int64? = nil,
    errorHolder: StreamErrorHolder? = nil,
    chunkSize: Int = 64 * 1024
  ) {
    self.source = source
    self.boundary = boundary
    self.metadataJson = metadataJson
    self.contentType = contentType
    self.totalSize = totalSize
    self.errorHolder = errorHolder
    self.chunkSize = chunkSize
  }

  struct AsyncIterator: AsyncIteratorProtocol {
    private enum State {
      case preamble
      case body
      case epilogue
      case done
    }

    private var state: State = .preamble
    private var source: S
    private let boundary: String
    private let metadataJson: Data
    private let contentType: String
    private let totalSize: Int64?
    private let errorHolder: StreamErrorHolder?
    private let chunkSize: Int
    private var bytesYielded: Int64 = 0

    init(
      source: S,
      boundary: String,
      metadataJson: Data,
      contentType: String,
      totalSize: Int64?,
      errorHolder: StreamErrorHolder?,
      chunkSize: Int
    ) {
      self.source = source
      self.boundary = boundary
      self.metadataJson = metadataJson
      self.contentType = contentType
      self.totalSize = totalSize
      self.errorHolder = errorHolder
      self.chunkSize = chunkSize
    }

    mutating func next() async throws -> NIOCore.ByteBuffer? {
      switch state {
      case .preamble:
        state = .body
        let preamble = "--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n"
        let middle = "\r\n--\(boundary)\r\nContent-Type: \(contentType)\r\n\r\n"
        let capacity = preamble.utf8.count + metadataJson.count + middle.utf8.count
        var buffer = ByteBufferAllocator().buffer(capacity: capacity)
        buffer.writeString(preamble)
        _ = metadataJson.withUnsafeBytes { buffer.writeBytes($0) }
        buffer.writeString(middle)
        return buffer

      case .body:
        let chunk: ByteBuffer?
        do {
          chunk = try await source.read(maxBytes: chunkSize)
        } catch {
          errorHolder?.streamError = error
          throw error
        }
        if let chunk = chunk, !chunk.isEmpty {
          bytesYielded += Int64(chunk.count)
          return chunk.byteBuffer
        }
        if let total = totalSize, bytesYielded < total {
          let err = UploadError.internalError("Failed to read data from source")
          errorHolder?.streamError = err
          throw err
        }
        state = .epilogue
        return try await next()

      case .epilogue:
        state = .done
        let epilogue = "\r\n--\(boundary)--\r\n"
        var buffer = ByteBufferAllocator().buffer(capacity: epilogue.utf8.count)
        buffer.writeString(epilogue)
        return buffer

      case .done:
        return nil
      }
    }
  }

  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(
      source: source,
      boundary: boundary,
      metadataJson: metadataJson,
      contentType: contentType,
      totalSize: totalSize,
      errorHolder: errorHolder,
      chunkSize: chunkSize
    )
  }
}
