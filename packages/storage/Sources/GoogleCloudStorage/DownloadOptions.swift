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

/// Specifies a byte range for ranged reads.
public enum ReadRange: Sendable, Hashable, Equatable {
  /// Read the entire object (default).
  case entire

  /// Read all bytes starting from `offset` to the end of the object (HTTP `bytes=N-`).
  case fromOffset(UInt64)

  /// Read the first `count` bytes of the object (HTTP `bytes=0-N`).
  case prefix(UInt64)

  /// Read the last `count` bytes of the object (HTTP `bytes=-N`).
  case suffix(UInt64)

  /// Read a bounded range of bytes from `start` to `end` inclusive (HTTP `bytes=start-end`).
  case bounded(start: UInt64, end: UInt64)

  /// Convenience initializer for Swift `ClosedRange<UInt64>`.
  public init(_ range: ClosedRange<UInt64>) {
    self = .bounded(start: range.lowerBound, end: range.upperBound)
  }

  /// Converts the range specification to an HTTP `Range` header value string.
  public var headerValue: String? {
    switch self {
    case .entire:
      return nil
    case .fromOffset(let offset):
      return "bytes=\(offset)-"
    case .prefix(let count):
      return count > 0 ? "bytes=0-\(count - 1)" : "bytes=0-0"
    case .suffix(let count):
      return "bytes=-\(count)"
    case .bounded(let start, let end):
      return "bytes=\(start)-\(end)"
    }
  }
}

/// Configuration options for object download (`readObject`) requests.
public struct ReadObjectOptions: Sendable {
  /// Object generation (`UInt64?`) to read a specific revision of an object.
  public var generation: UInt64?

  /// Preconditions to ensure operations execute only when condition constraints pass.
  public var preconditions: StoragePreconditions?

  /// Options for Customer-Supplied Encryption Keys (CSEK).
  public var customerEncryptionKey: CustomerEncryptionKeyOptions?

  /// Byte range for partial/ranged reads. Defaults to `.entire`.
  public var range: ReadRange = .entire

  /// Flag to disable automatic decompressive transcoding by GCS. Defaults to `false`.
  public var disableDecompressiveTranscoding: Bool = false

  /// Configuration options for download checksum validation.
  public var checksums: ChecksumOptions = .default

  /// Flag to enable transparent auto-resumption on transient network failures. Defaults to `true`.
  public var autoResume: Bool = true

  /// Default configuration options.
  public static var `default`: ReadObjectOptions { ReadObjectOptions() }

  public init() {}

  /// Builder pattern helper to modify configuration in place.
  public func with(_ config: (inout Self) -> Void) -> Self {
    var copy = self
    config(&copy)
    return copy
  }
}

/// Metadata attributes for an object returned in response headers during a download.
public struct ReadObjectMetadata: Sendable, Hashable, Equatable {
  public let bucket: String
  public let object: String
  public let size: Int64
  public let generation: Int64
  public let metageneration: Int64?
  public let etag: String?
  public let crc32c: String?
  public let md5Hash: String?
  public let contentType: String?
  public let contentEncoding: String?
  public let contentDisposition: String?
  public let storageClass: String?
  public let updated: Date?

  public init(
    bucket: String,
    object: String,
    size: Int64 = 0,
    generation: Int64 = 0,
    metageneration: Int64? = nil,
    etag: String? = nil,
    crc32c: String? = nil,
    md5Hash: String? = nil,
    contentType: String? = nil,
    contentEncoding: String? = nil,
    contentDisposition: String? = nil,
    storageClass: String? = nil,
    updated: Date? = nil
  ) {
    self.bucket = bucket
    self.object = object
    self.size = size
    self.generation = generation
    self.metageneration = metageneration
    self.etag = etag
    self.crc32c = crc32c
    self.md5Hash = md5Hash
    self.contentType = contentType
    self.contentEncoding = contentEncoding
    self.contentDisposition = contentDisposition
    self.storageClass = storageClass
    self.updated = updated
  }
}

/// An asynchronous sequence of `Data` chunks representing an object payload being downloaded.
public struct ReadObjectSequence: AsyncSequence, Sendable {
  public typealias Element = Data

  public let bucket: String
  public let object: String
  public let options: ReadObjectOptions

  public init(
    bucket: String,
    object: String,
    options: ReadObjectOptions = .init()
  ) {
    self.bucket = bucket
    self.object = object
    self.options = options
  }

  public struct AsyncIterator: AsyncIteratorProtocol, Sendable {
    public typealias Element = Data

    public mutating func next() async throws -> Data? {
      // Stub implementation
      return nil
    }
  }

  public func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator()
  }
}

/// Container object returned by `readObject` containing metadata and the streaming body sequence.
public struct ReadObjectResponse: Sendable {
  /// Object metadata extracted from initial HTTP response headers.
  public let metadata: ReadObjectMetadata

  /// Asynchronous sequence yielding chunks of binary data payload.
  public let body: ReadObjectSequence

  public init(metadata: ReadObjectMetadata, body: ReadObjectSequence) {
    self.metadata = metadata
    self.body = body
  }
}
