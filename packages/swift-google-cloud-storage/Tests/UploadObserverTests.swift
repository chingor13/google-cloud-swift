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
import GoogleCloudAuth
@_spi(GoogleCloudInternal) import GoogleCloudGax
@_spi(GoogleCloudInternal) @testable import GoogleCloudStorage
import Testing

@Suite struct UploadObserverTests {
  private func makeClient(
    registry: MockRegistry,
    clientObservers: [any UploadObserver] = []
  ) throws -> StorageClient {
    let options = StorageClientOptions().with {
      $0.client = .init().with {
        $0.endpoint = registry.endpoint
        $0.credentials = try! Credentials(configuration: .anonymous)
      }
      $0.upload.observers = clientObservers
    }
    return try StorageClient(options, mock: registry)
  }

  @Test func uploadProgressCalculations() {
    let knownProgress = UploadProgress(bytesUploaded: 500, totalBytes: 1000)
    #expect(knownProgress.bytesUploaded == 500)
    #expect(knownProgress.totalBytes == 1000)
    #expect(knownProgress.fractionCompleted == 0.5)

    let unknownProgress = UploadProgress(bytesUploaded: 500, totalBytes: nil)
    #expect(unknownProgress.bytesUploaded == 500)
    #expect(unknownProgress.totalBytes == nil)
    #expect(unknownProgress.fractionCompleted == nil)

    let zeroTotalProgress = UploadProgress(bytesUploaded: 0, totalBytes: 0)
    #expect(zeroTotalProgress.fractionCompleted == nil)
  }

  @Test func simpleUploadObserverLifecycle() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "test-object"
    let data = Data(repeating: 0xAB, count: 1024)
    let source = BytesSource(data: data)

    let simpleUploadUrl = registry.url(
      "/upload/storage/v1/b/\(bucket)/o?uploadType=multipart&name=\(objectName)")

    registry.register(
      response: .success(
        statusCode: 200,
        data: Data("{\"name\":\"\(objectName)\"}".utf8),
        headers: ["Content-Type": "application/json"]),
      for: simpleUploadUrl)

    let observer = RecordingUploadObserver()
    let client = try makeClient(registry: registry)

    let options = UploadOptions().with {
      $0.observers = [observer]
    }

    let object = try await client.upload(source, to: bucket, as: objectName, options: options)

    #expect(object.name == objectName)
    #expect(observer.startedCalls.count >= 1)
    #expect(observer.startedCalls.first?.bucket == bucket)
    #expect(observer.startedCalls.first?.object == objectName)

    #expect(observer.progressUpdates.count == 1)
    #expect(observer.progressUpdates.first?.bytesUploaded == 1024)
    #expect(observer.progressUpdates.first?.totalBytes == 1024)

    #expect(observer.completedObjects.count == 1)
    #expect(observer.completedObjects.first?.object.name == objectName)
    #expect(observer.completedObjects.first?.totalDuration ?? .zero >= .zero)
    #expect(observer.failures.isEmpty)
  }

  @Test func resumableUploadObserverLifecycle() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "test-object"
    let chunkSize = 256 * 1024
    let totalBytes = chunkSize * 2
    let data = Data(repeating: 0x42, count: totalBytes)
    let source = BytesSource(data: data)

    let startUrl = registry.url(
      "/upload/storage/v1/b/\(bucket)/o?uploadType=resumable&name=\(objectName)")
    let sessionUri = registry.url("/upload/storage/v1/session/12345")

    registry.register(
      response: .success(
        statusCode: 200,
        data: Data(),
        headers: ["Location": sessionUri.absoluteString]
      ),
      for: startUrl
    )

    registry.register(
      response: .success(
        statusCode: 308,
        data: Data(),
        headers: ["Range": "bytes=0-\(chunkSize - 1)"]
      ),
      for: sessionUri
    )

    registry.register(
      response: .success(
        statusCode: 200,
        data: Data("{\"name\":\"\(objectName)\",\"size\":\"\(totalBytes)\"}".utf8),
        headers: ["Content-Type": "application/json"]
      ),
      for: sessionUri
    )

    let observer = RecordingUploadObserver()
    let client = try makeClient(registry: registry)

    let options = UploadOptions().with {
      $0.chunkSize = chunkSize
      $0.resumableUploadThreshold = chunkSize
      $0.observers = [observer]
    }

    let object = try await client.upload(source, to: bucket, as: objectName, options: options)

    #expect(object.name == objectName)
    #expect(observer.startedCalls.count >= 1)
    #expect(observer.startedCalls.contains { $0.sessionId == sessionUri.absoluteString })

    #expect(observer.completedChunks.count == 2)
    #expect(observer.completedChunks[0].index == 0)
    #expect(observer.completedChunks[0].byteRange == 0..<Int64(chunkSize))
    #expect(observer.completedChunks[1].index == 1)
    #expect(observer.completedChunks[1].byteRange == Int64(chunkSize)..<Int64(totalBytes))

    #expect(observer.progressUpdates.count >= 2)
    #expect(observer.progressUpdates.last?.bytesUploaded == Int64(totalBytes))

    #expect(observer.completedObjects.count == 1)
    #expect(observer.completedObjects.first?.object.name == objectName)
    #expect(observer.failures.isEmpty)
  }

  @Test func uploadObserverRetryNotification() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "test-object"
    let data = Data(repeating: 1, count: 1024)
    let source = BytesSource(data: data)

    let simpleUploadUrl = registry.url(
      "/upload/storage/v1/b/\(bucket)/o?uploadType=multipart&name=\(objectName)")

    // First attempt fails with 503, second succeeds with 200
    registry.register(
      response: .success(
        statusCode: 503,
        data: Data("Service Unavailable".utf8),
        headers: nil),
      for: simpleUploadUrl)

    registry.register(
      response: .success(
        statusCode: 200,
        data: Data("{\"name\":\"\(objectName)\"}".utf8),
        headers: ["Content-Type": "application/json"]),
      for: simpleUploadUrl)

    let observer = RecordingUploadObserver()
    let client = try makeClient(registry: registry)

    let options = UploadOptions().with {
      $0.observers = [observer]
      $0.backoffPolicy = LinearBackoffPolicy(delay: .milliseconds(1))
    }

    let object = try await client.upload(source, to: bucket, as: objectName, options: options)

    #expect(object.name == objectName)
    #expect(observer.retries.count == 1)
    #expect(observer.retries.first?.attempt == 1)
    #expect(observer.completedObjects.count == 1)
    #expect(observer.failures.isEmpty)
  }

  @Test func uploadObserverFailureNotification() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "test-object"
    let data = Data(repeating: 1, count: 1024)
    let source = BytesSource(data: data)

    let simpleUploadUrl = registry.url(
      "/upload/storage/v1/b/\(bucket)/o?uploadType=multipart&name=\(objectName)")

    // Permanent failure 400 Bad Request
    registry.register(
      response: .success(
        statusCode: 400,
        data: Data("Bad Request".utf8),
        headers: nil),
      for: simpleUploadUrl)

    let observer = RecordingUploadObserver()
    let client = try makeClient(registry: registry)

    let options = UploadOptions().with {
      $0.observers = [observer]
    }

    await expectError(RequestError.self) {
      _ = try await client.upload(source, to: bucket, as: objectName, options: options)
    }

    #expect(observer.failures.count == 1)
    #expect(observer.completedObjects.isEmpty)
  }

  @Test func multipleObserversCombinedFromClientAndOptions() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "test-object"
    let data = Data(repeating: 1, count: 1024)
    let source = BytesSource(data: data)

    let simpleUploadUrl = registry.url(
      "/upload/storage/v1/b/\(bucket)/o?uploadType=multipart&name=\(objectName)")

    registry.register(
      response: .success(
        statusCode: 200,
        data: Data("{\"name\":\"\(objectName)\"}".utf8),
        headers: ["Content-Type": "application/json"]),
      for: simpleUploadUrl)

    let clientObserver = RecordingUploadObserver()
    let requestObserver = RecordingUploadObserver()

    let client = try makeClient(registry: registry, clientObservers: [clientObserver])

    let options = UploadOptions().with {
      $0.addObserver(requestObserver)
    }

    _ = try await client.upload(source, to: bucket, as: objectName, options: options)

    #expect(clientObserver.completedObjects.count == 1)
    #expect(requestObserver.completedObjects.count == 1)
    #expect(clientObserver.progressUpdates.count == 1)
    #expect(requestObserver.progressUpdates.count == 1)
  }

  @Test func defaultObserverMethodsNoOp() {
    struct EmptyObserver: UploadObserver {}
    let observer = EmptyObserver()
    observer.operationDidStart(context: StorageOperationContext(bucket: "b", object: "o"))
    observer.progressUpdated(UploadProgress(bytesUploaded: 10))
    observer.chunkDidComplete(index: 0, byteRange: 0..<10, duration: .zero)
    observer.operationDidRetry(
      attempt: 1, error: RequestError.http(HTTPDetails(http_status_code: 500, headers: [:])),
      backoff: .zero)
    observer.operationDidComplete(result: Object(), totalDuration: .zero)
    observer.operationDidFail(
      error: RequestError.http(HTTPDetails(http_status_code: 400, headers: [:])))
  }

  @Test func transferProgressProperties() {
    let uploadProgress = TransferProgress(bytesUploaded: 50, totalBytes: 100)
    #expect(uploadProgress.bytesUploaded == 50)
    #expect(uploadProgress.bytesTransferred == 50)
    #expect(uploadProgress.totalBytes == 100)
    #expect(uploadProgress.fractionCompleted == 0.5)

    let downloadProgress = TransferProgress(bytesDownloaded: 80, totalBytes: 100)
    #expect(downloadProgress.bytesDownloaded == 80)
    #expect(downloadProgress.bytesTransferred == 80)
    #expect(downloadProgress.totalBytes == 100)
    #expect(downloadProgress.fractionCompleted == 0.8)
  }

  @Test func genericOperationObserverWithCustomContext() {
    struct CustomContext: Sendable, Equatable {
      let operationName: String
    }
    struct CustomProgress: Sendable, Equatable {
      let step: Int
    }
    struct CustomResult: Sendable, Equatable {
      let success: Bool
    }

    let observer = RecordingOperationObserver<CustomContext, CustomProgress, CustomResult>()
    observer.operationDidStart(context: CustomContext(operationName: "custom-job"))
    observer.progressUpdated(CustomProgress(step: 1))
    observer.operationDidRetry(
      attempt: 1, error: RequestError.http(HTTPDetails(http_status_code: 503, headers: [:])),
      backoff: .seconds(1))
    observer.operationDidComplete(result: CustomResult(success: true), totalDuration: .seconds(5))

    #expect(observer.startedContexts.count == 1)
    #expect(observer.startedContexts.first?.operationName == "custom-job")
    #expect(observer.progressUpdates.count == 1)
    #expect(observer.progressUpdates.first?.step == 1)
    #expect(observer.retries.count == 1)
    #expect(observer.completedResults.count == 1)
    #expect(observer.completedResults.first?.result.success == true)
  }
}
