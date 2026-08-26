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

/// A handle to an ongoing upload, allowing for cancellation and awaiting the final result.
public struct UploadTask: Sendable {
  private let valueTask: Task<Object, any Error>

  internal init(valueTask: Task<Object, any Error>) {
    self.valueTask = valueTask
  }

  /// The final result of the upload.
  /// Awaiting this will suspend until the upload is complete.
  public var value: Object {
    get async throws {
      try await valueTask.value
    }
  }

  /// Cancels the ongoing upload (client-side).
  /// If cancelled, `value` will throw a `CancellationError`.
  /// Note: The GCS resumable session on the server will remain active until it expires (usually 7 days).
  public func cancel() {
    valueTask.cancel()
  }
}

// Internal factory to create an UploadTask
extension UploadTask {
  internal static func create(
    operation: @escaping @Sendable () async throws -> Object
  ) -> UploadTask {
    let valueTask = Task {
      try await operation()
    }
    return UploadTask(valueTask: valueTask)
  }
}
