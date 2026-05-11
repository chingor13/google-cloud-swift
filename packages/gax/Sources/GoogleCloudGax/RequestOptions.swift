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

/// The configuration for a request.
///
/// Use this type to override the client configuration during a single request.
public struct RequestOptions: Sendable {
  /// Create an instance without any overrides.
  public init() {}

  /// Override specific values using the `Then` idiom.
  ///
  /// ## Example
  /// ```
  /// let options = RequestOptions().with { $0.attemptTimeout = .seconds(3) }
  /// ```
  public func with(_ config: (inout Self) -> Void) -> Self {
    var copy = self
    config(&copy)
    return copy
  }

  /// Overrides the per-attempt timeout during this request.
  ///
  /// For methods that wrap RPCs, the client libraries make at least one attempt on the RPC. The timeout for each
  /// attempt is overridden using this value. Note that the overall time for the request is also controlled by the retry
  /// policy.
  public var attemptTimeout: Duration? = nil
}
