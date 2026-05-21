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

/// A retry policy decorator that limits the number of attempts.
///
/// This policy decorates an inner policy and limits the total number of attempts. Note that
/// `onError()` is not called before the initial (non-retry) attempt. Therefore, setting the maximum
/// number of attempts to 0 or 1 results in no retry attempts.
///
/// The policy passes through the results from the inner policy as long as
/// `attemptCount < maximumAttempts`.
///
/// Once the maximum number of attempts is reached, the policy replaces any
/// [.retry](``RetryResult/retry(_:)``) result with [.exhausted](``RetryResult/exhausted(_:)``).
public struct LimitedAttemptCount<P: RetryPolicy>: RetryPolicy {
  let inner: P
  let maximumAttempts: UInt32

  public init(inner: P, maximumAttempts: UInt32) {
    self.inner = inner
    self.maximumAttempts = maximumAttempts
  }

  public func onError(state: RetryState, error: RequestError) -> RetryResult {
    switch inner.onError(state: state, error: error) {
    case .permanent(let e):
      return .permanent(e)
    case .exhausted(let e):
      return .exhausted(e)
    case .retry(let e):
      if state.attemptCount >= maximumAttempts {
        return .exhausted(e)
      }
      return .retry(e)
    }
  }

  public func onThrottle(state: RetryState, error: RequestError) -> ThrottleResult {
    // The retry loop only calls `onThrottle()` if the policy has not been exhausted.
    inner.onThrottle(state: state, error: error)
  }

  public func remainingTime(state: RetryState) -> Duration? {
    inner.remainingTime(state: state)
  }
}

extension RetryPolicy {
  /// Decorate a `RetryPolicy` to limit the number of retry attempts.
  ///
  /// - Parameter maximumAttempts: The maximum number of attempts allowed by the policy.
  /// - Returns: A decorated retry policy.
  public func withAttemptLimit(_ maximumAttempts: UInt32) -> LimitedAttemptCount<Self> {
    LimitedAttemptCount(inner: self, maximumAttempts: maximumAttempts)
  }
}
