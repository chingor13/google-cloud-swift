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
import GoogleRpc

/// A retry policy decorator that continues on `ResourceExhausted` or `TOO_MANY_REQUESTS`.
///
/// This policy returns [retry][RetryResult.retry] when the error is a `ResourceExhausted` (or
/// `TOO_MANY_REQUESTS` if received from the HTTP layer). Otherwise it returns the result from the
/// inner retry policy.
public struct TooManyRequests<P: RetryPolicy>: RetryPolicy {
  let inner: P

  public init(inner: P) {
    self.inner = inner
  }

  public func onError(state: RetryState, error: RequestError) -> RetryResult {
    if error.isResourceExhausted || error.isTooManyRequests {
      return .retry(error)
    }
    return inner.onError(state: state, error: error)
  }

  public func onThrottle(state: RetryState, error: RequestError) -> ThrottleResult {
    inner.onThrottle(state: state, error: error)
  }

  public func remainingTime(state: RetryState) -> Duration? {
    inner.remainingTime(state: state)
  }
}

extension RetryPolicy {
  /// Decorate a `RetryPolicy` to continue on certain status codes.
  ///
  /// This policy decorates an inner policy and retries any errors with HTTP status code
  /// "429 - TOO_MANY_REQUESTS" **or** where the service returns an error with code
  /// `ResourceExhausted`.
  ///
  /// For other errors it returns the same value as the inner policy.
  public func retryOnTooManyRequests() -> TooManyRequests<Self> {
    TooManyRequests(inner: self)
  }
}

extension RequestError {
  fileprivate var isResourceExhausted: Bool {
    if case .service(let details) = self {
      return details.code == GoogleRpc.Code.resourceExhausted.rawValue
    }
    return false
  }

  fileprivate var isTooManyRequests: Bool {
    if case .http(let details) = self {
      return details.http_status_code == 429
    }
    return false
  }
}
