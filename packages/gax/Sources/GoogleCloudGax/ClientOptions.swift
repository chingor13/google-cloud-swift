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
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

import GoogleCloudAuth

/// The configuration for a new client.
///
/// Use this type to configure clients in the Google Cloud client libraries for Swift libraries.
public struct ClientOptions: Sendable {
  /// Create an instance without any overrides.
  public init() {}

  /// Override specific values using the `Then` idiom.
  ///
  /// ## Example
  /// ```
  /// let options = ClientOptions().with { $0.endpoint = "https://private.googleapis.com" }
  /// ```
  public func with(_ config: (inout Self) -> Void) -> Self {
    var copy = self
    config(&copy)
    return copy
  }

  /// Overrides the default endpoint for the client.
  ///
  /// Each client defines a default endpoint (typically `https://${service}.googleapis.com`), applications may need to
  /// override in many circumstances, including:
  /// - Using a regional endpoint, such as `https://${service}.${region}.rep.googleapis.com`.
  /// - Using a locational endpoint, such as `https://${service}-${region}.googleapis.com`.
  /// - Using the API in a VPC-SC environment, where `https://private.googleapis.com` serves as the endpoint for all
  ///   APIs.
  /// - Using the API against an emulator or some other test environment.
  ///
  /// Use this option to override the default endpoint.
  public var endpoint: String? = nil

  /// Overrides the default credentials for the client.
  ///
  /// ``Credentials`` defines how the client authenticates to Google Cloud APIs. Without an override, the client uses
  /// [Application Default Credentials]. This works well in most deployment and development environments, use this
  /// override if your application cannot use the default.
  ///
  /// [Application Default Credentials]: https://docs.cloud.google.com/docs/authentication/client-libraries
  public var credentials: Credentials? = nil
}
