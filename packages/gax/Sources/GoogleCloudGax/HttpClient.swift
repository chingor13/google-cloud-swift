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

import AsyncHTTPClient
import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif
import GoogleCloudAuth
import NIOHTTP1

/// Implements a HTTP-only client for the Swift SDK client libraries.
public struct HTTPClient {
  let baseURL: URLComponents
  let credentials: GoogleCloudAuth.Credentials
  let inner: AsyncHTTPClient.HTTPClient

  // Creates a new client.
  public init(from: ClientOptions, withDefaultEndpoint: String) throws {
    self.credentials = try from.credentials ?? GoogleCloudAuth.Credentials()
    let endpoint = from.endpoint ?? withDefaultEndpoint
    self.baseURL = try Self.validateEndpoint(endpoint)
    self.inner = from._httpClient ?? AsyncHTTPClient.HTTPClient.shared
  }

  // Creates a new testing client.
  init(httpClient: AsyncHTTPClient.HTTPClient, endpoint: String, credentials: Credentials? = nil)
    throws
  {
    self.baseURL = try Self.validateEndpoint(endpoint)
    self.credentials = try credentials ?? GoogleCloudAuth.Credentials(configuration: .anonymous)
    self.inner = httpClient
  }

  static func validateEndpoint(_ endpoint: String) throws -> URLComponents {
    guard var parsed = URLComponents(string: endpoint) else {
      throw ClientError.invalidEndpoint(endpoint)
    }
    parsed.queryItems = nil
    parsed.path = ""
    guard let scheme = parsed.scheme, (scheme == "http" || scheme == "https") else {
      throw ClientError.invalidEndpoint(endpoint)
    }
    guard let host = parsed.host, !host.isEmpty else {
      throw ClientError.invalidEndpoint(endpoint)
    }
    return parsed
  }

  public func Request(path: String, query: [URLQueryItem]) async throws -> HTTPClientRequest {
    var components = self.baseURL
    components.path = path
    components.queryItems = query
    guard let url = components.url else {
      throw RequestError.binding("bad URL for path=\(path), baseURL=\(self.baseURL)")
    }
    var request = HTTPClientRequest(url: url.absoluteString)
    let headers = try await self.credentials.headers()
    for (key, value) in headers {
      request.headers.add(name: key, value: value)
    }
    return request
  }

  public func rpc(for request: HTTPClientRequest) async -> Result<
    (Data, HTTPURLResponse), RequestError
  > {
    do {
      let (data, response) = try await self.data(for: request)
      if !(200..<300).contains(response.statusCode) {
        return .failure(Self.parseError(data: data, response: response))
      }
      return .success((data, response))
    } catch let e as RequestError {
      return .failure(e)
    } catch let e {
      return .failure(.io(e))
    }
  }

  public func data(for request: HTTPClientRequest) async throws -> (Data, HTTPURLResponse) {
    do {
      let response = try await self.inner.execute(request, timeout: .seconds(30))
      let buffer = try await response.body.collect(upTo: 100 * 1024 * 1024)
      let data = Data(buffer.readableBytesView)
      var headerFields: [String: String] = [:]
      for header in response.headers {
        headerFields[header.name] = header.value
      }
      guard let url = URL(string: request.url),
        let httpResponse = HTTPURLResponse(
          url: url,
          statusCode: Int(response.status.code),
          httpVersion: nil,
          headerFields: headerFields
        )
      else {
        throw RequestError.badResponseType
      }
      return (data, httpResponse)
    } catch let error as RequestError {
      throw error
    } catch {
      throw RequestError.io(error)
    }
  }

  static func parseError(data: Data, response: HTTPURLResponse) -> RequestError {
    if let s = response.value(forHTTPHeaderField: "Content-Type"), s.contains("application/json") {
      if let w = ErrorWrapper(data: data, response: response) {
        return RequestError.service(ServiceError(wrapper: w))
      }
    }
    var headers: [String: String] = [:]
    for (k, v) in response.allHeaderFields {
      if let key = k as? String, let value = v as? String {
        headers[key] = value
      }
    }
    return GoogleCloudGax.RequestError.http(
      GoogleCloudGax.HTTPDetails(
        http_status_code: response.statusCode,
        headers: headers,
        payload: data
      ))
  }
}
