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

/// Contextual information about a Cloud Storage operation.
public struct StorageOperationContext: Sendable, Equatable {
  /// The target Cloud Storage bucket name.
  public var bucket: String

  /// The target Cloud Storage object name.
  public var object: String

  /// An optional session ID (e.g. GCS Resumable Upload URI).
  public var sessionId: String?

  /// Creates a new `StorageOperationContext` instance.
  public init(bucket: String, object: String, sessionId: String? = nil) {
    self.bucket = bucket
    self.object = object
    self.sessionId = sessionId
  }
}

/// Typealias for storage operation context.
public typealias OperationContext = StorageOperationContext

/// Progress information for a data transfer operation (such as an upload or download).
public struct TransferProgress: Sendable, Equatable {
  /// The number of bytes successfully transferred so far.
  public let bytesTransferred: Int64

  /// The total size of the payload in bytes, if known.
  public let totalBytes: Int64?

  /// The fraction of the transfer completed (0.0 to 1.0), or `nil` if the total size is unknown.
  public var fractionCompleted: Double? {
    guard let totalBytes = totalBytes, totalBytes > 0 else { return nil }
    return Double(bytesTransferred) / Double(totalBytes)
  }

  /// Creates a new `TransferProgress` instance.
  public init(bytesTransferred: Int64, totalBytes: Int64? = nil) {
    self.bytesTransferred = bytesTransferred
    self.totalBytes = totalBytes
  }

  /// Semantic initializer for uploads.
  public init(bytesUploaded: Int64, totalBytes: Int64? = nil) {
    self.init(bytesTransferred: bytesUploaded, totalBytes: totalBytes)
  }

  /// Semantic property for uploads.
  public var bytesUploaded: Int64 {
    bytesTransferred
  }

  /// Semantic initializer for downloads.
  public init(bytesDownloaded: Int64, totalBytes: Int64? = nil) {
    self.init(bytesTransferred: bytesDownloaded, totalBytes: totalBytes)
  }

  /// Semantic property for downloads.
  public var bytesDownloaded: Int64 {
    bytesTransferred
  }
}

/// Typealias for upload progress information.
public typealias UploadProgress = TransferProgress

/// Typealias for download progress information.
public typealias DownloadProgress = TransferProgress

/// A generic protocol for observing lifecycle, progress, and resilience events during multi-step or resumable operations.
public protocol OperationObserver<Context, Progress, Result>: Sendable {
  associatedtype Context: Sendable
  associatedtype Progress: Sendable
  associatedtype Result: Sendable

  /// Called when an operation begins or a session is established.
  ///
  /// - Parameter context: Contextual details identifying the operation.
  func operationDidStart(context: Context)

  /// Called whenever transfer or operation progress advances.
  ///
  /// - Parameter progress: The current progress details.
  func progressUpdated(_ progress: Progress)

  /// Called when an operation encounters a transient error and enters a retry/resume cycle.
  ///
  /// - Parameters:
  ///   - attempt: The consecutive retry/resume attempt count.
  ///   - error: The transient error that occurred.
  ///   - backoff: The backoff sleep duration before the next attempt.
  func operationDidRetry(attempt: Int, error: any Error, backoff: Duration)

  /// Called when the entire operation completes successfully.
  ///
  /// - Parameters:
  ///   - result: The final output of the operation.
  ///   - totalDuration: The total elapsed duration of the operation.
  func operationDidComplete(result: Result, totalDuration: Duration)

  /// Called when the operation fails permanently.
  ///
  /// - Parameter error: The fatal error that caused the operation to fail.
  func operationDidFail(error: any Error)
}

extension OperationObserver {
  public func operationDidStart(context: Context) {}
  public func progressUpdated(_ progress: Progress) {}
  public func operationDidRetry(attempt: Int, error: any Error, backoff: Duration) {}
  public func operationDidComplete(result: Result, totalDuration: Duration) {}
  public func operationDidFail(error: any Error) {}
}
