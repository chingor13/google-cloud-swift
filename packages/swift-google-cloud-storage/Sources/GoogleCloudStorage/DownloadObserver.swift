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

/// A protocol for observing lifecycle, progress, and resilience events during Cloud Storage downloads.
public protocol DownloadObserver: OperationObserver
where Context == StorageOperationContext, Progress == DownloadProgress, Result == ReadObjectMetadata
{
  /// Called when a download operation begins or headers are parsed.
  ///
  /// - Parameters:
  ///   - bucket: The target Cloud Storage bucket name.
  ///   - object: The target Cloud Storage object name.
  func downloadDidStart(bucket: String, object: String)

  /// Called whenever download byte progress advances.
  ///
  /// - Parameter progress: The current download progress details.
  func downloadProgressUpdated(_ progress: DownloadProgress)

  /// Called when a chunk of data is received during a streaming download.
  ///
  /// - Parameters:
  ///   - bytes: The number of bytes in the received chunk.
  ///   - totalReceived: The total number of bytes received so far.
  func chunkDidReceive(bytes: Int, totalReceived: Int64)

  /// Called when a download encounters a transient error and enters a retry/resume cycle.
  ///
  /// - Parameters:
  ///   - attempt: The consecutive retry/resume attempt count.
  ///   - error: The transient error that occurred.
  ///   - backoff: The backoff sleep duration before the next attempt.
  func downloadDidRetry(attempt: Int, error: any Error, backoff: Duration)

  /// Called when the entire download operation completes successfully.
  ///
  /// - Parameters:
  ///   - metadata: The final metadata of the downloaded object.
  ///   - totalDuration: The total elapsed duration of the download operation.
  func downloadDidComplete(metadata: ReadObjectMetadata, totalDuration: Duration)

  /// Called when the download operation fails permanently.
  ///
  /// - Parameter error: The fatal error that caused the download to fail.
  func downloadDidFail(error: any Error)
}

extension DownloadObserver {
  public func downloadDidStart(bucket: String, object: String) {}
  public func downloadProgressUpdated(_ progress: DownloadProgress) {}
  public func chunkDidReceive(bytes: Int, totalReceived: Int64) {}
  public func downloadDidRetry(attempt: Int, error: any Error, backoff: Duration) {}
  public func downloadDidComplete(metadata: ReadObjectMetadata, totalDuration: Duration) {}
  public func downloadDidFail(error: any Error) {}

  public func operationDidStart(context: OperationContext) {
    downloadDidStart(bucket: context.bucket, object: context.object)
  }

  public func progressUpdated(_ progress: DownloadProgress) {
    downloadProgressUpdated(progress)
  }

  public func operationDidRetry(attempt: Int, error: any Error, backoff: Duration) {
    downloadDidRetry(attempt: attempt, error: error, backoff: backoff)
  }

  public func operationDidComplete(result: ReadObjectMetadata, totalDuration: Duration) {
    downloadDidComplete(metadata: result, totalDuration: totalDuration)
  }

  public func operationDidFail(error: any Error) {
    downloadDidFail(error: error)
  }
}

/// Composite observer that dispatches events to multiple download observers.
package struct _CompositeDownloadObserver: DownloadObserver, Sendable {
  package let observers: [any DownloadObserver]

  package init(_ observers: [any DownloadObserver]) {
    self.observers = observers
  }

  package func operationDidStart(context: OperationContext) {
    for observer in observers {
      observer.operationDidStart(context: context)
    }
  }

  package func downloadDidStart(bucket: String, object: String) {
    for observer in observers {
      observer.downloadDidStart(bucket: bucket, object: object)
    }
  }

  package func progressUpdated(_ progress: DownloadProgress) {
    for observer in observers {
      observer.progressUpdated(progress)
    }
  }

  package func downloadProgressUpdated(_ progress: DownloadProgress) {
    for observer in observers {
      observer.downloadProgressUpdated(progress)
    }
  }

  package func chunkDidReceive(bytes: Int, totalReceived: Int64) {
    for observer in observers {
      observer.chunkDidReceive(bytes: bytes, totalReceived: totalReceived)
    }
  }

  package func operationDidRetry(attempt: Int, error: any Error, backoff: Duration) {
    for observer in observers {
      observer.operationDidRetry(attempt: attempt, error: error, backoff: backoff)
    }
  }

  package func downloadDidRetry(attempt: Int, error: any Error, backoff: Duration) {
    for observer in observers {
      observer.downloadDidRetry(attempt: attempt, error: error, backoff: backoff)
    }
  }

  package func operationDidComplete(result: ReadObjectMetadata, totalDuration: Duration) {
    for observer in observers {
      observer.operationDidComplete(result: result, totalDuration: totalDuration)
    }
  }

  package func downloadDidComplete(metadata: ReadObjectMetadata, totalDuration: Duration) {
    for observer in observers {
      observer.downloadDidComplete(metadata: metadata, totalDuration: totalDuration)
    }
  }

  package func operationDidFail(error: any Error) {
    for observer in observers {
      observer.operationDidFail(error: error)
    }
  }

  package func downloadDidFail(error: any Error) {
    for observer in observers {
      observer.downloadDidFail(error: error)
    }
  }
}
