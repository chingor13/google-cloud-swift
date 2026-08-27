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

/// Information about a retry attempt during an operation.
public struct RetryDetails: Sendable {
  /// The consecutive retry/resume attempt count (1-based).
  public var attempt: Int

  /// The transient error that occurred.
  public var error: any Error

  /// The backoff sleep duration before the next attempt.
  public var backoff: Duration

  /// Creates a new `RetryDetails` instance.
  public init(attempt: Int, error: any Error, backoff: Duration) {
    self.attempt = attempt
    self.error = error
    self.backoff = backoff
  }
}

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
  /// - Parameter retry: Details of the retry attempt including attempt number, transient error, and backoff.
  func operationDidRetry(_ retry: RetryDetails)

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
  public func operationDidRetry(_ retry: RetryDetails) {}
  public func operationDidComplete(result: Result, totalDuration: Duration) {}
  public func operationDidFail(error: any Error) {}
}
