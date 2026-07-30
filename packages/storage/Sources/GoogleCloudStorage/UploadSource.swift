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

import Crypto
import Foundation

/// Represents a data source that can be read from sequentially.
public protocol UploadSource: Sendable {
  /// Reads the next chunk of data, up to `maxBytes`.
  /// Returns `nil` when the source is exhausted.
  mutating func read(maxBytes: Int) async throws -> Data?

  /// The total size of the source, if known.
  var totalSize: Int64? { get }
}

/// Represents an upload source that supports seeking (rewinding/skipping).
/// Conformance to this protocol enables persistent resumption.
public protocol SeekableUploadSource: UploadSource {
  /// Seeks to a specific byte offset.
  mutating func seek(to offset: Int64) async throws
}

extension SeekableUploadSource {
  /// Computes full-source checksums when resuming an upload from an intermediate offset.
  package mutating func computeChecksums(options: ChecksumOptions) async throws -> ChecksumOptions {
    let needCRC32C = (options.crc32c == .auto)
    let needMD5 = (options.md5 == .auto)

    if !needCRC32C && !needMD5 {
      return options
    }

    try await self.seek(to: 0)

    var crc32c = CRC32C()
    var md5 = Insecure.MD5()

    let bufferSize = 8 * 1024 * 1024
    while let chunk = try await self.read(maxBytes: bufferSize), !chunk.isEmpty {
      if needCRC32C {
        crc32c.update(chunk)
      }
      if needMD5 {
        md5.update(data: chunk)
      }
    }

    var resultCRC32C = options.crc32c
    if needCRC32C {
      let bigEndian = crc32c.finalize().bigEndian
      var bytes = [UInt8]()
      withUnsafeBytes(of: bigEndian) { bytes = Array($0) }
      resultCRC32C = .value(Data(bytes).base64EncodedString())
    }

    var resultMD5 = options.md5
    if needMD5 {
      let digest = md5.finalize()
      resultMD5 = .value(Data(digest).base64EncodedString())
    }

    return ChecksumOptions(crc32c: resultCRC32C, md5: resultMD5)
  }
}

/// An upload source that reads from a local file.
public struct FileSource: SeekableUploadSource {
  public let fileURL: URL
  private var offset: Int64 = 0

  public var totalSize: Int64? {
    do {
      let values = try fileURL.resourceValues(forKeys: [.fileSizeKey])
      return values.fileSize.map { Int64($0) }
    } catch {
      return nil
    }
  }

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  public mutating func read(maxBytes: Int) async throws -> Data? {
    let handle = try FileHandle(forReadingFrom: fileURL)
    defer {
      try? handle.close()
    }
    try handle.seek(toOffset: UInt64(offset))
    guard let data = try handle.read(upToCount: maxBytes), !data.isEmpty else {
      return nil
    }
    offset += Int64(data.count)
    return data
  }

  public mutating func seek(to offset: Int64) async throws {
    guard offset >= 0 else {
      throw UploadError.internalError("Invalid seek offset: \(offset)")
    }
    if let size = totalSize, offset > size {
      throw UploadError.localSourceTooSmall(localSize: size, gcsOffset: offset)
    }
    self.offset = offset
  }
}

/// An upload source that wraps in-memory Data.
public struct BytesSource: SeekableUploadSource {
  public let data: Data
  public var totalSize: Int64? {
    return Int64(data.count)
  }
  private var offset: Int64 = 0

  public init(data: Data) {
    self.data = data
  }

  public mutating func read(maxBytes: Int) async throws -> Data? {
    guard offset < data.count else { return nil }
    let end = min(offset + Int64(maxBytes), Int64(data.count))
    let chunk = data.subdata(in: Int(offset)..<Int(end))
    offset = end
    return chunk
  }

  public mutating func seek(to offset: Int64) async throws {
    guard offset >= 0 else {
      throw UploadError.internalError("Invalid seek offset: \(offset)")
    }
    let size = Int64(data.count)
    guard offset <= size else {
      throw UploadError.localSourceTooSmall(localSize: size, gcsOffset: offset)
    }
    self.offset = offset
  }
}

/// An upload source that wraps an arbitrary AsyncSequence of Data chunks.
public struct StreamSource<S: AsyncSequence>: UploadSource
where S.Element == Data, S: Sendable, S.AsyncIterator: Sendable {
  public var totalSize: Int64? { return nil }
  private var iterator: S.AsyncIterator?
  private var buffer = Data()

  public init(sequence: S) {
    self.iterator = sequence.makeAsyncIterator()
  }

  public mutating func read(maxBytes: Int) async throws -> Data? {
    while buffer.count < maxBytes {
      guard var iterator = self.iterator else {
        break
      }
      guard let nextChunk = try await iterator.next() else {
        self.iterator = nil
        break
      }
      buffer.append(nextChunk)
      self.iterator = iterator
    }

    guard !buffer.isEmpty else {
      return nil
    }

    let chunkSize = min(maxBytes, buffer.count)
    let chunk = buffer.subdata(in: 0..<chunkSize)
    buffer.removeSubrange(0..<chunkSize)
    return chunk
  }
}
