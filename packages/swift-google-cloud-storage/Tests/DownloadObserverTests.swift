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
import GoogleCloudGax
import NIOHTTP1
@_spi(GoogleCloudInternal) @testable import GoogleCloudStorage
import Testing

@Suite struct DownloadObserverTests {
  private func makeClient(
    registry: MockRegistry,
    clientObservers: [any DownloadObserver] = []
  ) throws -> StorageClient {
    let options = StorageClientOptions().with {
      $0.client = .init().with {
        $0.endpoint = registry.endpoint
        $0.credentials = try! Credentials(configuration: .anonymous)
      }
      $0.download.observers = clientObservers
    }
    return try StorageClient(options, mock: registry)
  }

  @Test func downloadObserverLifecycle() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "test-file.txt"
    let content = "Hello Download Observer Test Content!"
    let data = Data(content.utf8)

    let url = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")
    registry.register(
      response: .success(
        statusCode: 200,
        data: data,
        headers: [
          "Content-Length": String(data.count),
          "Content-Type": "text/plain",
          "ETag": "etag-12345",
        ]
      ),
      for: url
    )

    let observer = RecordingDownloadObserver()
    let client = try makeClient(registry: registry)
    let options = ReadObjectOptions().with {
      $0.observers = [observer]
    }

    let task = client.readObject(from: bucket, object: objectName, options: options)
    var downloadedData = Data()
    for try await chunk in task.body {
      downloadedData.append(contentsOf: chunk.readableBytesView)
    }

    #expect(downloadedData == data)
    #expect(observer.startedCalls.count == 1)
    #expect(observer.startedCalls.first?.bucket == bucket)
    #expect(observer.startedCalls.first?.object == objectName)

    #expect(!observer.receivedChunks.isEmpty)
    #expect(observer.progressUpdates.last?.bytesDownloaded == Int64(data.count))
    #expect(observer.progressUpdates.last?.totalBytes == Int64(data.count))
    #expect(observer.progressUpdates.last?.fractionCompleted == 1.0)

    #expect(observer.completedMetadata.count == 1)
    #expect(observer.completedMetadata.first?.metadata.object == objectName)
    #expect(observer.failures.isEmpty)
  }

  @Test func downloadObserverFailureNotification() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "non-existent.txt"

    let url = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")
    registry.register(
      response: .success(
        statusCode: 404,
        data: Data("Not Found".utf8),
        headers: ["Content-Type": "text/plain"]
      ),
      for: url
    )

    let observer = RecordingDownloadObserver()
    let client = try makeClient(registry: registry)
    let options = ReadObjectOptions().with {
      $0.observers = [observer]
    }

    let task = client.readObject(from: bucket, object: objectName, options: options)
    await #expect(throws: (any Error).self) {
      for try await _ in task.body {}
    }

    #expect(observer.failures.count >= 1)
    #expect(observer.completedMetadata.isEmpty)
  }

  @Test func multipleDownloadObserversCombinedFromClientAndOptions() async throws {
    let registry = MockRegistry.create()
    let bucket = "test-bucket"
    let objectName = "combined.txt"
    let data = Data("Multi observer test".utf8)

    let url = registry.url("/storage/v1/b/\(bucket)/o/\(objectName)?alt=media")
    registry.register(
      response: .success(
        statusCode: 200,
        data: data,
        headers: [
          "Content-Length": String(data.count),
          "Content-Type": "text/plain",
        ]
      ),
      for: url
    )

    let clientObserver = RecordingDownloadObserver()
    let requestObserver = RecordingDownloadObserver()

    let client = try makeClient(registry: registry, clientObservers: [clientObserver])
    let options = ReadObjectOptions().with {
      $0.observers = [requestObserver]
    }

    let task = client.readObject(from: bucket, object: objectName, options: options)
    for try await _ in task.body {}

    #expect(clientObserver.startedCalls.count == 1)
    #expect(requestObserver.startedCalls.count == 1)
    #expect(clientObserver.completedMetadata.count == 1)
    #expect(requestObserver.completedMetadata.count == 1)
  }

  @Test func defaultObserverMethodsNoOp() {
    struct EmptyObserver: DownloadObserver {}
    let observer = EmptyObserver()
    observer.operationDidStart(context: StorageOperationContext(bucket: "b", object: "o"))
    observer.progressUpdated(DownloadProgress(bytesDownloaded: 10))
    observer.chunkDidReceive(bytes: 10, totalReceived: 10)
    observer.operationDidRetry(
      attempt: 1, error: RequestError.http(HTTPDetails(http_status_code: 500, headers: [:])),
      backoff: .zero)
    observer.operationDidComplete(result: ReadObjectMetadata(), totalDuration: .zero)
    observer.operationDidFail(
      error: RequestError.http(HTTPDetails(http_status_code: 400, headers: [:])))
  }
}
