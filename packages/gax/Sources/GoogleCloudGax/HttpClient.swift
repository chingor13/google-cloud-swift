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
// On Linux `URLSession` and friends are found in `FoundationNetworking`, ugh.
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import GoogleCloudAuth

/// Implements a HTTP-only client for the Swift SDK client libraries.
public struct HTTPClient {
  let endpoint: String
  let credentials: GoogleCloudAuth.Credentials
  let inner: URLSession

  // Creates a new client.
  public init(from: ClientOptions, withDefaultEndpoint: String) throws {
    self.credentials = try from.credentials ?? GoogleCloudAuth.Credentials()
    self.endpoint = from.endpoint ?? withDefaultEndpoint
    self.inner = URLSession(configuration: .ephemeral)
  }

  // Creates a new testing client.
  init(testSession: URLSession, endpoint: String, credentials: Credentials? = nil) throws {
    self.endpoint = endpoint
    self.credentials = try credentials ?? GoogleCloudAuth.Credentials(configuration: .anonymous)
    self.inner = testSession
  }

  // TODO(https://github.com/googleapis/librarian/issues/5929) - remove old initializers.
  public init(
    endpoint: String, credentials: GoogleCloudAuth.Credentials? = nil, session: URLSession? = nil,
  ) throws {
    self.credentials = try credentials ?? GoogleCloudAuth.Credentials()
    self.endpoint = endpoint
    self.inner = session ?? URLSession(configuration: .ephemeral)
  }

  public func Request(path: String, query: [URLQueryItem]) async throws -> URLRequest {
    guard var components = URLComponents(string: "\(self.endpoint)\(path)") else {
      throw RequestError.binding("bad URL with endpoint=\(self.endpoint) and path=\(path)")
    }
    components.queryItems = query
    guard let url = components.url else {
      throw RequestError.binding("bad URL with endpoint=\(self.endpoint) and path=\(path)")
    }
    var request = URLRequest(url: url)
    let headers = try await self.credentials.headers()
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }
    return request
  }

  public func data(for: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await self.inner.data(for: `for`)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw RequestError.badResponseType
    }
    return (data, httpResponse)
  }
}
