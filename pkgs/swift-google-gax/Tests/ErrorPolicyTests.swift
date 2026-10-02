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
import GoogleGax
import Testing

@Suite struct ErrorPolicyTests {
  private func assertIsRetryPolicy<T: RetryPolicy>(_: T) {}

  private func assertIsPollingErrorPolicy<T: PollingErrorPolicy>(_: T) {}

  private func assertIsErrorPolicy<T: ErrorPolicy>(_: T) {}

  @Test func leafRetryPoliciesConformToErrorPolicy() {
    assertIsRetryPolicy(AIP194.unbounded())
    assertIsRetryPolicy(AlwaysRetry.unbounded())
    assertIsRetryPolicy(NeverRetry())
    assertIsRetryPolicy(BaseRetryPolicy.unbounded())
  }

  @Test func leafPollingPoliciesConformToErrorPolicy() {
    assertIsPollingErrorPolicy(AIP194.unbounded())
    assertIsPollingErrorPolicy(AlwaysPoll.unbounded())
    assertIsPollingErrorPolicy(BasePollingErrorPolicy.unbounded())
  }

  @Test func retryDecoratorsConformToErrorPolicy() {
    let base = NeverRetry()
    assertIsRetryPolicy(ContinueOnIO(inner: base))
    assertIsRetryPolicy(TooManyRequests(inner: base))
    assertIsRetryPolicy(LimitedAttemptCount(inner: base, maximumAttempts: 3))
    assertIsRetryPolicy(LimitedElapsedTime(inner: base, maximumDuration: .seconds(30)))
    assertIsRetryPolicy(StrictIdempotency(inner: base))
  }

  @Test func pollingDecoratorsConformToErrorPolicy() {
    let base = AlwaysPoll.unbounded()
    assertIsPollingErrorPolicy(ContinueOnIO(inner: base))
    assertIsPollingErrorPolicy(TooManyRequests(inner: base))
    assertIsPollingErrorPolicy(LimitedAttemptCount(inner: base, maximumAttempts: 3))
    assertIsPollingErrorPolicy(LimitedElapsedTime(inner: base, maximumDuration: .seconds(30)))
  }

  @Test func nestedDecoratorsConformToErrorPolicy() {
    let chainedRetry = NeverRetry()
      .retryOnIO()
      .retryOnTooManyRequests()
      .strictIdempotency()
      .withTimeLimit(.seconds(10))
      .withAttemptLimit(3)
    assertIsRetryPolicy(chainedRetry)

    let chainedPolling = AlwaysPoll.unbounded()
      .continueOnIO()
      .continueOnTooManyRequests()
      .withTimeLimit(.seconds(10))
      .withAttemptLimit(3)
    assertIsPollingErrorPolicy(chainedPolling)

    // Verify manual instantiation of nested decorator structs directly conforms to ErrorPolicy
    let manualNested = LimitedAttemptCount(
      inner: LimitedElapsedTime(
        inner: TooManyRequests(
          inner: ContinueOnIO(
            inner: NeverRetry()
          )
        ),
        maximumDuration: .seconds(10)
      ),
      maximumAttempts: 5
    )
    assertIsRetryPolicy(manualNested)
    assertIsErrorPolicy(manualNested)
  }
}
