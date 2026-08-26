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

/// Progress information for a Cloud Storage data transfer operation (such as an upload or download).
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
