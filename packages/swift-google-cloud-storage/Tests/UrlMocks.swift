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
import AsyncHTTPClient
import NIOCore
import NIOHTTP1
import Testing
@_spi(GoogleCloudInternal) @testable import GoogleCloudGax
@_spi(GoogleCloudInternal) @testable import GoogleCloudStorage

enum MockResponse: Sendable {
  case success(statusCode: Int, data: Data, headers: [String: String]? = nil)
  case stream(
    statusCode: Int, chunks: [Data], error: (any Error)? = nil, headers: [String: String]? = nil)
  case failure(any Error)
}

struct MockNetworkError: Error, Sendable, Equatable {}

/// Recorded HTTP request during testing
struct RecordedRequest: Sendable {
  let urlString: String
  let method: NIOHTTP1.HTTPMethod
  let headers: NIOHTTP1.HTTPHeaders
  let body: Data?

  var url: URL? {
    URL(string: urlString)
  }

  var httpMethod: String {
    method.rawValue
  }

  var httpBody: Data? {
    body
  }

  func value(forHTTPHeaderField name: String) -> String? {
    headers.first(name: name)
  }

  var urlComponents: URLComponents? {
    URLComponents(string: urlString)
  }
}

/// Mock UploadSource that can throw errors
struct MockUploadSource: SeekableUploadSource {
  var data: Data
  var totalSize: Int64?
  var readError: (any Error)?
  var seekError: (any Error)?
  private var offset: Int64 = 0

  init(
    data: Data, totalSize: Int64? = nil, readError: (any Error)? = nil,
    seekError: (any Error)? = nil
  ) {
    self.data = data
    self.totalSize = totalSize ?? Int64(data.count)
    self.readError = readError
    self.seekError = seekError
  }

  mutating func read(maxBytes: Int) async throws -> Data? {
    if let error = readError {
      throw error
    }
    guard offset < data.count else { return nil }
    let end = min(offset + Int64(maxBytes), Int64(data.count))
    let chunk = data.subdata(in: Int(offset)..<Int(end))
    offset = end
    return chunk
  }

  mutating func seek(to offset: Int64) async throws {
    if let error = seekError {
      throw error
    }
    guard offset >= 0 && offset <= data.count else {
      throw UploadError.internalError("Invalid seek offset: \(offset)")
    }
    self.offset = offset
  }
}

func makeObjectJSON(
  name: String = "test-object", bucket: String = "test-bucket", size: Int = 10 * 1024 * 1024
) -> Data {
  let json = """
    {
      "name": "\(name)",
      "bucket": "\(bucket)",
      "generation": "1",
      "metageneration": "1",
      "size": "\(size)",
      "contentType": "application/octet-stream",
      "storageClass": "STANDARD"
    }
    """
  return Data(json.utf8)
}

/// Helper to assert that an async action throws an error of type `E` and returns the caught error.
@discardableResult
func expectError<E: Error>(
  _ errorType: E.Type = E.self,
  performing action: () async throws -> Any?
) async -> E? {
  do {
    _ = try await action()
    Issue.record("Expected error of type \(E.self) to be thrown")
    return nil
  } catch let error as E {
    return error
  } catch {
    Issue.record("Expected error of type \(E.self), but got \(error)")
    return nil
  }
}

/// Helper to assert that an async action throws an `UploadError` and returns the caught error.
@discardableResult
func expectUploadError(
  performing action: () async throws -> Any?
) async -> UploadError? {
  await expectError(UploadError.self, performing: action)
}

/// A thread-safe registry to store mocks for a specific test run
final class MockRegistry: _HTTPClientProtocol, @unchecked Sendable {
  let id: String
  private let lock = NSLock()
  private var mocks: [String: [MockResponse]] = [:]
  private var requests: [RecordedRequest] = []

  static func create() -> MockRegistry {
    let id = "test-" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    return MockRegistry(id: id)
  }

  private init(id: String) {
    self.id = id
  }

  var endpoint: String {
    "http://\(id)"
  }

  func url(_ path: String) -> URL {
    let p = path.hasPrefix("/") ? path : "/\(path)"
    return URL(string: "\(endpoint)\(p)")!
  }

  func register(response: MockResponse, for url: URL) {
    register(response: response, for: url.absoluteString)
  }

  func register(response: MockResponse, for urlString: String) {
    lock.withLock {
      self.mocks[urlString, default: []].append(response)
    }
  }

  func recordedRequests() -> [RecordedRequest] {
    lock.withLock {
      self.requests
    }
  }

  func lastRequest(for url: URL) -> RecordedRequest? {
    lastRequest(for: url.absoluteString)
  }

  func lastRequest(for urlString: String) -> RecordedRequest? {
    lock.withLock {
      self.requests.last(where: { $0.urlString == urlString })
    }
  }

  func execute(
    request: AsyncHTTPClient.HTTPClientRequest,
    timeout: Duration
  ) async throws -> AsyncHTTPClient.HTTPClientResponse {
    let bodyData: Data?
    if let body = request.body {
      let buffer = try await body.collect(upTo: 32 * 1024 * 1024)
      bodyData = Data(buffer: buffer)
    } else {
      bodyData = nil
    }

    let recorded = RecordedRequest(
      urlString: request.url,
      method: request.method,
      headers: request.headers,
      body: bodyData
    )

    let mockResponse: MockResponse? = lock.withLock {
      self.requests.append(recorded)
      if var responses = self.mocks[request.url], !responses.isEmpty {
        let resp = responses.removeFirst()
        self.mocks[request.url] = responses
        return resp
      }
      return nil
    }

    guard let mock = mockResponse else {
      throw GoogleCloudGax.RequestError.http(
        GoogleCloudGax.HTTPDetails(
          http_status_code: 404,
          headers: [:],
          payload: Data("Mock not found for \(request.url)".utf8)
        )
      )
    }

    switch mock {
    case .success(let statusCode, let data, let headers):
      var nioHeaders = NIOHTTP1.HTTPHeaders()
      if let headers {
        for (key, value) in headers {
          nioHeaders.add(name: key, value: value)
        }
      }
      return AsyncHTTPClient.HTTPClientResponse(
        version: .http1_1,
        status: NIOHTTP1.HTTPResponseStatus(statusCode: statusCode),
        headers: nioHeaders,
        body: .bytes(NIOCore.ByteBuffer(data: data))
      )
    case .stream(let statusCode, let chunks, let error, let headers):
      var nioHeaders = NIOHTTP1.HTTPHeaders()
      if let headers {
        for (key, value) in headers {
          nioHeaders.add(name: key, value: value)
        }
      }
      let stream = AsyncThrowingStream<NIOCore.ByteBuffer, any Error> { continuation in
        for chunk in chunks {
          continuation.yield(NIOCore.ByteBuffer(data: chunk))
        }
        if let error {
          continuation.finish(throwing: error)
        } else {
          continuation.finish()
        }
      }
      return AsyncHTTPClient.HTTPClientResponse(
        version: .http1_1,
        status: NIOHTTP1.HTTPResponseStatus(statusCode: statusCode),
        headers: nioHeaders,
        body: .stream(stream)
      )
    case .failure(let error):
      throw error
    }
  }
}

final class RecordingUploadObserver: UploadObserver, @unchecked Sendable {
  private let lock = NSLock()

  var startedCalls: [(bucket: String, object: String, uploadId: String?)] = []
  var progressUpdates: [UploadProgress] = []
  var completedChunks: [(index: Int, byteRange: Range<Int64>, duration: Duration)] = []
  var retries: [(attempt: Int, error: any Error, backoff: Duration)] = []
  var completedObjects: [(object: Object, totalDuration: Duration)] = []
  var failures: [any Error] = []

  func uploadDidStart(bucket: String, object: String, uploadId: String?) {
    lock.lock()
    defer { lock.unlock() }
    startedCalls.append((bucket: bucket, object: object, uploadId: uploadId))
  }

  func uploadProgressUpdated(_ progress: UploadProgress) {
    lock.lock()
    defer { lock.unlock() }
    progressUpdates.append(progress)
  }

  func chunkDidComplete(index: Int, byteRange: Range<Int64>, duration: Duration) {
    lock.lock()
    defer { lock.unlock() }
    completedChunks.append((index: index, byteRange: byteRange, duration: duration))
  }

  func uploadDidRetry(attempt: Int, error: any Error, backoff: Duration) {
    lock.lock()
    defer { lock.unlock() }
    retries.append((attempt: attempt, error: error, backoff: backoff))
  }

  func uploadDidComplete(object: Object, totalDuration: Duration) {
    lock.lock()
    defer { lock.unlock() }
    completedObjects.append((object: object, totalDuration: totalDuration))
  }

  func uploadDidFail(error: any Error) {
    lock.lock()
    defer { lock.unlock() }
    failures.append(error)
  }
}

final class RecordingDownloadObserver: DownloadObserver, @unchecked Sendable {
  private let lock = NSLock()

  var startedCalls: [(bucket: String, object: String)] = []
  var progressUpdates: [DownloadProgress] = []
  var receivedChunks: [(bytes: Int, totalReceived: Int64)] = []
  var retries: [(attempt: Int, error: any Error, backoff: Duration)] = []
  var completedMetadata: [(metadata: ReadObjectMetadata, totalDuration: Duration)] = []
  var failures: [any Error] = []

  func downloadDidStart(bucket: String, object: String) {
    lock.lock()
    defer { lock.unlock() }
    startedCalls.append((bucket: bucket, object: object))
  }

  func downloadProgressUpdated(_ progress: DownloadProgress) {
    lock.lock()
    defer { lock.unlock() }
    progressUpdates.append(progress)
  }

  func chunkDidReceive(bytes: Int, totalReceived: Int64) {
    lock.lock()
    defer { lock.unlock() }
    receivedChunks.append((bytes: bytes, totalReceived: totalReceived))
  }

  func downloadDidRetry(attempt: Int, error: any Error, backoff: Duration) {
    lock.lock()
    defer { lock.unlock() }
    retries.append((attempt: attempt, error: error, backoff: backoff))
  }

  func downloadDidComplete(metadata: ReadObjectMetadata, totalDuration: Duration) {
    lock.lock()
    defer { lock.unlock() }
    completedMetadata.append((metadata: metadata, totalDuration: totalDuration))
  }

  func downloadDidFail(error: any Error) {
    lock.lock()
    defer { lock.unlock() }
    failures.append(error)
  }
}

final class RecordingOperationObserver<Context: Sendable, Progress: Sendable, Result: Sendable>:
  OperationObserver,
  @unchecked Sendable
{
  private let lock = NSLock()

  var startedContexts: [Context] = []
  var progressUpdates: [Progress] = []
  var retries: [(attempt: Int, error: any Error, backoff: Duration)] = []
  var completedResults: [(result: Result, totalDuration: Duration)] = []
  var failures: [any Error] = []

  func operationDidStart(context: Context) {
    lock.lock()
    defer { lock.unlock() }
    startedContexts.append(context)
  }

  func progressUpdated(_ progress: Progress) {
    lock.lock()
    defer { lock.unlock() }
    progressUpdates.append(progress)
  }

  func operationDidRetry(attempt: Int, error: any Error, backoff: Duration) {
    lock.lock()
    defer { lock.unlock() }
    retries.append((attempt: attempt, error: error, backoff: backoff))
  }

  func operationDidComplete(result: Result, totalDuration: Duration) {
    lock.lock()
    defer { lock.unlock() }
    completedResults.append((result: result, totalDuration: totalDuration))
  }

  func operationDidFail(error: any Error) {
    lock.lock()
    defer { lock.unlock() }
    failures.append(error)
  }
}
