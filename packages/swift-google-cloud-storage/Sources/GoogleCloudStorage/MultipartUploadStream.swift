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
@_spi(GoogleCloudInternal) import GoogleCloudGax
import NIOCore

/// An AsyncSequence that frames an UploadSource with multipart/related boundaries on the fly.
struct MultipartUploadStream: AsyncSequence, Sendable {
  typealias Element = NIOCore.ByteBuffer

  let source: any UploadSource
  let boundary: String
  let metadataJson: Data
  let contentType: String
  let totalSize: Int64?
  let chunkSize: Int

  init(
    source: any UploadSource,
    boundary: String,
    metadataJson: Data,
    contentType: String,
    totalSize: Int64? = nil,
    chunkSize: Int = 64 * 1024
  ) {
    self.source = source
    self.boundary = boundary
    self.metadataJson = metadataJson
    self.contentType = contentType
    self.totalSize = totalSize
    self.chunkSize = chunkSize
  }

  /// Computes the exact Content-Length for the multipart request body, if the total size is known.
  var bodyLength: _HTTPBodyLength {
    guard let total = totalSize else { return .unknown }
    let preambleLen =
      "--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8.count
      + metadataJson.count
      + "\r\n--\(boundary)\r\nContent-Type: \(contentType)\r\n\r\n".utf8.count
    let epilogueLen = "\r\n--\(boundary)--\r\n".utf8.count
    return .known(Int64(preambleLen) + total + Int64(epilogueLen))
  }

  /// Prepares an upload source for a simple multipart upload by calculating or extracting the `x-goog-hash` header.
  ///
  /// The GCS JSON API simple upload endpoint requires the `x-goog-hash` header to be sent in the initial HTTP request
  /// headers before the request body is received. This helper computes or extracts the required checksum, prepares
  /// the source for streaming, and constructs the `MultipartUploadStream`.
  static func prepare<S: UploadSource>(
    source: S,
    boundary: String,
    metadataJson: Data,
    contentType: String,
    totalSize: Int64?,
    options: ChecksumOptions,
    chunkSize: Int = 64 * 1024
  ) async throws -> (stream: MultipartUploadStream, checksum: String?, totalSize: Int64?) {
    var calculators = options.makeUploadCalculators()

    // 1. Checksum validation disabled: No checksum header needed, stream source directly with zero overhead.
    guard !calculators.isEmpty else {
      let stream = MultipartUploadStream(
        source: source,
        boundary: boundary,
        metadataJson: metadataJson,
        contentType: contentType,
        totalSize: totalSize,
        chunkSize: chunkSize
      )
      return (stream, nil, totalSize)
    }

    // 2. Precomputed / user-provided checksums: Values are already known upfront from options,
    // so format the header immediately without reading or inspecting the source data.
    let autoCalculators = calculators.filter { !($0 is ProvidedChecksumCalculator) }
    if autoCalculators.isEmpty {
      let checksumStr = calculators.map { "\($0.algorithmName)=\($0.finalize())" }.joined(
        separator: ", ")
      let stream = MultipartUploadStream(
        source: source,
        boundary: boundary,
        metadataJson: metadataJson,
        contentType: contentType,
        totalSize: totalSize,
        chunkSize: chunkSize
      )
      return (stream, checksumStr, totalSize)
    }

    // 3. In-memory data (BytesSource): Hash the buffer directly in memory without extra copies or stream consumption.
    if let bytesSource = source as? BytesSource {
      for i in calculators.indices {
        calculators[i].update(bytesSource.buffer)
      }
      let checksumStr = calculators.map { "\($0.algorithmName)=\($0.finalize())" }.joined(
        separator: ", ")
      let effectiveTotal = totalSize ?? Int64(bytesSource.buffer.count)
      let stream = MultipartUploadStream(
        source: bytesSource,
        boundary: boundary,
        metadataJson: metadataJson,
        contentType: contentType,
        totalSize: effectiveTotal,
        chunkSize: chunkSize
      )
      return (stream, checksumStr, effectiveTotal)
    }

    // 4. 0-byte payload: Compute the hash of an empty buffer immediately without reading from the source.
    if source.totalSize == 0 {
      for i in calculators.indices {
        calculators[i].update(ByteBuffer())
      }
      let checksumStr = calculators.map { "\($0.algorithmName)=\($0.finalize())" }.joined(
        separator: ", ")
      let effectiveTotal = totalSize ?? 0
      let stream = MultipartUploadStream(
        source: source,
        boundary: boundary,
        metadataJson: metadataJson,
        contentType: contentType,
        totalSize: effectiveTotal,
        chunkSize: chunkSize
      )
      return (stream, checksumStr, effectiveTotal)
    }

    // 5. Seekable source (e.g. FileSource): Read and hash chunks in a pre-read pass, then rewind
    // to offset 0 with seek(to:) so the source can be streamed directly from disk with O(1) memory.
    if var seekable = source as? (any SeekableUploadSource) {
      do {
        while let chunk = try await seekable.read(maxBytes: 64 * 1024) {
          for i in calculators.indices {
            calculators[i].update(chunk)
          }
        }
        try await seekable.seek(to: 0)
      } catch {
        if let uploadError = error as? UploadError {
          throw uploadError
        }
        throw UploadError.sourceReadFailed(underlyingError: error)
      }
      let checksumStr = calculators.map { "\($0.algorithmName)=\($0.finalize())" }.joined(
        separator: ", ")
      let effectiveTotal = totalSize ?? seekable.totalSize
      let stream = MultipartUploadStream(
        source: seekable,
        boundary: boundary,
        metadataJson: metadataJson,
        contentType: contentType,
        totalSize: effectiveTotal,
        chunkSize: chunkSize
      )
      return (stream, checksumStr, effectiveTotal)
    }

    // 6. Non-seekable stream (e.g. StreamSource): Since non-seekable streams cannot be rewound and simple uploads
    // are bounded by the simple upload threshold (<= 8 MiB), buffer the chunks into memory while computing the hash,
    // then stream the resulting BytesSource.
    var nonSeekable = source
    var buffer = NIOCore.ByteBuffer()
    do {
      while let chunk = try await nonSeekable.read(maxBytes: 64 * 1024) {
        for i in calculators.indices {
          calculators[i].update(chunk)
        }
        var nio = chunk.byteBuffer
        buffer.writeBuffer(&nio)
      }
    } catch {
      if let uploadError = error as? UploadError {
        throw uploadError
      }
      throw UploadError.sourceReadFailed(underlyingError: error)
    }
    let checksumStr = calculators.map { "\($0.algorithmName)=\($0.finalize())" }.joined(
      separator: ", ")
    let bytesSource = BytesSource(buffer: ByteBuffer(buffer))
    let effectiveTotal = Int64(buffer.readableBytes)
    let stream = MultipartUploadStream(
      source: bytesSource,
      boundary: boundary,
      metadataJson: metadataJson,
      contentType: contentType,
      totalSize: effectiveTotal,
      chunkSize: chunkSize
    )
    return (stream, checksumStr, effectiveTotal)
  }

  struct AsyncIterator: AsyncIteratorProtocol {
    private enum State {
      case preamble
      case body
      case epilogue
      case done
    }

    private var state: State = .preamble
    private var source: any UploadSource
    private let boundary: String
    private let metadataJson: Data
    private let contentType: String
    private let totalSize: Int64?
    private let chunkSize: Int
    private var bytesYielded: Int64 = 0

    init(
      source: any UploadSource,
      boundary: String,
      metadataJson: Data,
      contentType: String,
      totalSize: Int64?,
      chunkSize: Int
    ) {
      self.source = source
      self.boundary = boundary
      self.metadataJson = metadataJson
      self.contentType = contentType
      self.totalSize = totalSize
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
          if let uploadError = error as? UploadError {
            throw uploadError
          }
          throw UploadError.sourceReadFailed(underlyingError: error)
        }
        if let chunk = chunk, !chunk.isEmpty {
          bytesYielded += Int64(chunk.count)
          return chunk.byteBuffer
        }
        if let total = totalSize, bytesYielded < total {
          throw UploadError.internalError("Failed to read data from source")
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
      chunkSize: chunkSize
    )
  }
}
