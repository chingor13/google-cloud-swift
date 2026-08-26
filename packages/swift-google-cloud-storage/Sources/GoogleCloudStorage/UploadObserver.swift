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

/// Progress information for an ongoing upload operation.
public struct UploadProgress: Sendable, Equatable {
  /// The number of bytes successfully uploaded or committed so far.
  public let bytesUploaded: Int64

  /// The total size of the object being uploaded in bytes, if known.
  public let totalBytes: Int64?

  /// The fraction of the upload completed (0.0 to 1.0), or `nil` if the total size is unknown.
  public var fractionCompleted: Double? {
    guard let totalBytes = totalBytes, totalBytes > 0 else { return nil }
    return Double(bytesUploaded) / Double(totalBytes)
  }

  /// Creates a new `UploadProgress` instance.
  ///
  /// - Parameters:
  ///   - bytesUploaded: The number of bytes uploaded so far.
  ///   - totalBytes: The total number of bytes to upload, if known.
  public init(bytesUploaded: Int64, totalBytes: Int64? = nil) {
    self.bytesUploaded = bytesUploaded
    self.totalBytes = totalBytes
  }
}

/// A protocol for observing lifecycle, progress, and resilience events during Cloud Storage uploads.
public protocol UploadObserver: Sendable {
  /// Called when an upload operation begins or a session is established.
  ///
  /// - Parameters:
  ///   - bucket: The target Cloud Storage bucket name.
  ///   - object: The target Cloud Storage object name.
  ///   - uploadId: The GCS resumable upload session URI if established, or `nil` for simple uploads.
  func uploadDidStart(bucket: String, object: String, uploadId: String?)

  /// Called whenever upload byte progress advances.
  ///
  /// - Parameter progress: The current upload progress details.
  func uploadProgressUpdated(_ progress: UploadProgress)

  /// Called when a single chunk upload completes successfully in a resumable upload.
  ///
  /// - Parameters:
  ///   - index: The zero-based index of the chunk uploaded in this session.
  ///   - byteRange: The byte range uploaded in this chunk (e.g. `0..<8388608`).
  ///   - duration: The time taken to upload this chunk.
  func chunkDidComplete(index: Int, byteRange: Range<Int64>, duration: Duration)

  /// Called when an upload encounters a transient error and enters a retry/resume cycle.
  ///
  /// - Parameters:
  ///   - attempt: The consecutive retry/resume attempt count.
  ///   - error: The transient error that occurred.
  ///   - backoff: The backoff sleep duration before the next attempt.
  func uploadDidRetry(attempt: Int, error: any Error, backoff: Duration)

  /// Called when the entire upload operation completes successfully.
  ///
  /// - Parameters:
  ///   - object: The created Cloud Storage object metadata.
  ///   - totalDuration: The total elapsed duration of the upload operation.
  func uploadDidComplete(object: Object, totalDuration: Duration)

  /// Called when the upload operation fails permanently.
  ///
  /// - Parameter error: The fatal error that caused the upload to fail.
  func uploadDidFail(error: any Error)
}

extension UploadObserver {
  public func uploadDidStart(bucket: String, object: String, uploadId: String?) {}
  public func uploadProgressUpdated(_ progress: UploadProgress) {}
  public func chunkDidComplete(index: Int, byteRange: Range<Int64>, duration: Duration) {}
  public func uploadDidRetry(attempt: Int, error: any Error, backoff: Duration) {}
  public func uploadDidComplete(object: Object, totalDuration: Duration) {}
  public func uploadDidFail(error: any Error) {}
}

/// Composite observer that dispatches events to multiple observers.
package struct _CompositeUploadObserver: UploadObserver, Sendable {
  package let observers: [any UploadObserver]

  package init(_ observers: [any UploadObserver]) {
    self.observers = observers
  }

  package func uploadDidStart(bucket: String, object: String, uploadId: String?) {
    for observer in observers {
      observer.uploadDidStart(bucket: bucket, object: object, uploadId: uploadId)
    }
  }

  package func uploadProgressUpdated(_ progress: UploadProgress) {
    for observer in observers {
      observer.uploadProgressUpdated(progress)
    }
  }

  package func chunkDidComplete(index: Int, byteRange: Range<Int64>, duration: Duration) {
    for observer in observers {
      observer.chunkDidComplete(index: index, byteRange: byteRange, duration: duration)
    }
  }

  package func uploadDidRetry(attempt: Int, error: any Error, backoff: Duration) {
    for observer in observers {
      observer.uploadDidRetry(attempt: attempt, error: error, backoff: backoff)
    }
  }

  package func uploadDidComplete(object: Object, totalDuration: Duration) {
    for observer in observers {
      observer.uploadDidComplete(object: object, totalDuration: totalDuration)
    }
  }

  package func uploadDidFail(error: any Error) {
    for observer in observers {
      observer.uploadDidFail(error: error)
    }
  }
}
