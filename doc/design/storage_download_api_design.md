# Design Document: GCS Swift Client Library Download API

This document outlines the API design for downloading objects using the Google Cloud Storage (GCS) Swift client library.

## Goal

Provide a language-idiomatic, memory-safe, high-performance, and resilient API for reading and downloading object contents from Cloud Storage in Swift.

---

## 1. Client Surface & Async Streaming Interface

We want to expose a simple, intuitive client interface for reading object contents while leveraging Swift Concurrency's `AsyncSequence` for streaming data.

### Decision
The primary client method for downloading object content is `readObject`:

```swift
func readObject(
  from bucket: String,
  object: String,
  options: ReadObjectOptions = .init()
) -> ReadObjectSequence
```

- **Return Type:** Returns a custom struct `ReadObjectSequence` that conforms to `AsyncSequence` where `Element == Data`.
- **Non-blocking Initialization:** Calling `readObject` immediately returns the `ReadObjectSequence` handle without blocking. Network requests and data streaming begin when the caller iterates over the sequence.

### Example Usage

### Basic download with default options:

```swift
for try await chunk in client.readObject(from: "my-bucket", object: "file.txt") {
  // process Data chunk
}
```

### Custom download options:

```swift
let options = ReadObjectOptions().with {
  $0.range = .bounded(start: 0, end: 1024)
  $0.autoResume = true
}

for try await chunk in client.readObject(from: "my-bucket", object: "file.txt", options: options) {
  // process Data chunk
}
```

---

## 2. Target Object & Read Options

Developers need full control over target object selection, precondition checks, and encryption options.

### Key Options in `ReadObjectOptions`
1. **Target Object Identification:**
   - `bucket`: Bucket name containing the object.
   - `object`: Object name/path within the bucket.
   - `generation`: Optional object generation (`UInt64?`) to read a specific revision of an object.
2. **Preconditions:**
   - Leverages `StoragePreconditions` (`ifGenerationMatch`, `ifGenerationNotMatch`, `ifMetagenerationMatch`, `ifMetagenerationNotMatch`) to ensure operations execute only when condition constraints pass.
3. **Customer-Supplied Encryption Keys (CSEK):**
   - Leverages `CustomerEncryptionKeyOptions` to send required encryption headers (`x-goog-encryption-algorithm`, `x-goog-encryption-key`, `x-goog-encryption-key-sha256`) when reading customer-encrypted objects.

---

## 3. Ranged Reads & Byte Ranges

To support partial object downloads, parallel chunk downloads, or reading file footers (e.g. Parquet metadata), the API must support flexible ranged reads.

### The `ReadRange` Abstraction

Ranged reads are configured via the `ReadRange` enum:

```swift
public enum ReadRange: Sendable, Hashable, Equatable {
  /// Read the entire object (default).
  case entire

  /// Read all bytes starting from `offset` to the end of the object (HTTP `bytes=N-`).
  case fromOffset(UInt64)

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
    case .suffix(let count):
      return "bytes=-\(count)"
    case .bounded(let start, let end):
      return "bytes=\(start)-\(end)"
    }
  }
}
```

---

## 4. Decompressive Transcoding & Compressed Objects

Objects uploaded to GCS with `Content-Encoding: gzip` are automatically decompressed by GCS during download (decompressive transcoding) unless the client explicitly disables it.

### Decision
The `ReadObjectOptions` struct provides a `disableDecompressiveTranscoding: Bool` flag (default `false`):
- When `false` (default): GCS decompresses the object on-the-fly before sending payload bytes to the client.
- When `true`: The client adds `Accept-Encoding: gzip` to request headers. GCS delivers the raw compressed bytes without decompressing.

---

## 5. Checksum Validation (CRC32C & MD5)

To guarantee data integrity during transfer, Cloud Storage provides CRC32C and MD5 hashes in response headers (`x-goog-hash` or `ETag`).

### Rules & Defaults
1. **CRC32C (Default Enabled):** When performing full object reads (without ranged bounds or decompressive transcoding), the client automatically accumulates CRC32C checksums of received chunks on-the-fly and compares against `x-goog-hash` upon stream completion.
2. **MD5 (Optional):** Applications can explicitly enable MD5 validation in `DownloadChecksumOptions`.
3. **Automatic Bypass:** Checksum validation is automatically skipped when performing partial/ranged reads or when decompressive transcoding is active, because GCS header hashes reflect the entire raw object payload.

### `DownloadChecksumOptions` Interface

```swift
public struct DownloadChecksumOptions: Sendable, Hashable, Equatable {
  /// Automatically validate CRC32C checksum on full reads.
  public var crc32c: Bool = true

  /// Automatically validate MD5 checksum when requested.
  public var md5: Bool = false

  public init() {}

  public static var `default`: DownloadChecksumOptions { DownloadChecksumOptions() }
  public static var none: DownloadChecksumOptions {
    DownloadChecksumOptions().with {
      $0.crc32c = false
      $0.md5 = false
    }
  }

  public func with(_ config: (inout Self) -> Void) -> Self {
    var copy = self
    config(&copy)
    return copy
  }
}
```

---

## 6. Resumability & Error Handling

Transient network failures during large object downloads should not require restarting the entire transfer from byte 0.

### Resumption Protocol Strategy
1. **Offset Tracking:** As chunks of `Data` are yielded by the `AsyncIterator`, the iterator tracks total `bytesReceived`.
2. **Re-connection Range:** On a transient connection drop or socket error, if `autoResume` is enabled (default `true`), the iterator transparently initiates a new HTTP GET request requesting range `bytes={rangeStart + bytesReceived}-`.
3. **Generation Lock:** To avoid reading corrupted or mismatched data if the object was updated mid-download, the resumption request includes `ifGenerationMatch={generation}` using the object's generation returned in the initial response header.
4. **Failure Handling:** If resumption fails (e.g., generation changed, object deleted, non-retryable status), a `DownloadError.resumeFailed` error is thrown through the stream.

---

## 7. Proposed Swift Interface

Below is the complete proposed public API surface for object downloads in `GoogleCloudStorage`.

### Options & Range Types

```swift
/// Specifies a byte range for ranged reads.
public enum ReadRange: Sendable, Hashable, Equatable {
  case entire
  case fromOffset(UInt64)
  case suffix(UInt64)
  case bounded(start: UInt64, end: UInt64)

  public init(_ range: ClosedRange<UInt64>)
  public var headerValue: String? { get }
}

/// Configuration options for download checksum validation.
public struct DownloadChecksumOptions: Sendable, Hashable, Equatable {
  public var crc32c: Bool = true
  public var md5: Bool = false

  public init() {}
  public static var `default`: DownloadChecksumOptions { get }
  public static var none: DownloadChecksumOptions { get }

  public func with(_ config: (inout Self) -> Void) -> Self
}

/// Configuration options for object download (`readObject`) requests.
public struct ReadObjectOptions: Sendable {
  public var generation: UInt64?
  public var preconditions: StoragePreconditions?
  public var customerEncryptionKey: CustomerEncryptionKeyOptions?
  public var range: ReadRange = .entire
  public var disableDecompressiveTranscoding: Bool = false
  public var checksums: DownloadChecksumOptions = .default
  public var autoResume: Bool = true

  public static var `default`: ReadObjectOptions { ReadObjectOptions() }

  public init() {}

  public func with(_ config: (inout Self) -> Void) -> Self
}
```

### Errors

```swift
/// Errors thrown by object read and download operations.
public enum DownloadError: Error, Sendable, Equatable {
  case checksumMismatch(expected: String, actual: String, algorithm: String)
  case invalidRange(String)
  case resumeFailed(bytesReceived: UInt64, message: String)
  case unexpectedServerResponse(statusCode: Int, message: String)
}
```

### Stream Sequence

```swift
/// An asynchronous sequence of `Data` chunks representing an object payload being downloaded.
public struct ReadObjectSequence: AsyncSequence, Sendable {
  public typealias Element = Data

  public let bucket: String
  public let object: String
  public let options: ReadObjectOptions

  public struct AsyncIterator: AsyncIteratorProtocol, Sendable {
    public typealias Element = Data
    public mutating func next() async throws -> Data?
  }

  public func makeAsyncIterator() -> AsyncIterator
}
```

### StorageClient Extensions & Protocols

```swift
public protocol StorageClientProtocol {
  func readObject(
    from bucket: String,
    object: String,
    options: ReadObjectOptions
  ) -> ReadObjectSequence
}

extension StorageClientProtocol {
  public func readObject(
    from bucket: String,
    object: String
  ) -> ReadObjectSequence {
    readObject(from: bucket, object: object, options: .init())
  }
}

extension StorageClient {
  public func readObject(
    from bucket: String,
    object: String,
    options: ReadObjectOptions = .init()
  ) -> ReadObjectSequence {
    ReadObjectSequence(bucket: bucket, object: object, options: options)
  }
}
```

---

## 8. Alternatives Considered

### Option A: `AsyncSequence<UInt8>` for Streaming
- *Description:* Yield byte-by-byte values (`UInt8`) in `AsyncSequence`.
- *Why Rejected:* **Severe performance overhead.** Technical evaluation confirmed that yielding single bytes over Swift async iteration introduces excessive context-switching and task scheduling overhead. Streaming `Data` chunks (buffer blocks) provides vastly higher throughput.

### Option B: Synchronous Download `readObject(...) -> Data`
- *Description:* Download the entire object payload into memory and return a single `Data` value.
- *Why Rejected:* **High memory consumption.** Large GCS objects (e.g. gigabytes in size) would cause memory exhaustion. Callers requiring in-memory data can easily accumulate chunks from `readObject` into `Data` when appropriate.

### Option C: Explicit Resume Token / Manual Handshake
- *Description:* Require developers to catch errors and manually initiate resume downloads with an offset token.
- *Why Rejected:* Unnecessary boilerplate for developers. Encapsulating transparent auto-resumption inside `ReadObjectSequence.AsyncIterator` ensures high reliability out of the box while allowing manual control when `autoResume = false`.

### Option D: Opaque Return Type (`some AsyncSequence<Data, any Error> & Sendable`)
- *Description:* Use Swift 5.7+ opaque return types (`func readObject(...) -> some AsyncSequence<Data, any Error> & Sendable`) instead of exposing `ReadObjectSequence`.
- *Trade-offs:*
  - *Pros:* Hides internal implementation details and allows changing the underlying stream implementation in future releases without breaking API signature compatibility.
  - *Cons:* In Swift protocol declarations (`StorageClientProtocol`), returning `some` forces all conforming implementations (including test mocks) to use the exact same underlying concrete type, or requires adding an `associatedtype` requirement to the protocol.
- *Recommendation:* If `StorageClientProtocol` needs flexibility across different mock implementations without complex protocol generic constraints, returning `ReadObjectSequence` or `any AsyncSequence<Data, any Error> & Sendable` (or an `AsyncThrowingStream<Data, Error>`) is preferable.
