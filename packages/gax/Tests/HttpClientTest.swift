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
import Testing
@testable import GoogleCloudGax
import GoogleCloudAuth

@Suite struct HttpClientTest {
  // Custom URLProtocol to mock responses
  class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
      return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
      return request
    }

    override func startLoading() {
      guard let handler = MockURLProtocol.requestHandler else {
        fatalError("Handler not set.")
      }

      do {
        let (response, data) = try handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
      } catch {
        client?.urlProtocol(self, didFailWithError: error)
      }
    }

    override func stopLoading() {}
  }

  @Test func testPostRequest() async throws {
    let endpoint = "http://localhost:8080"
    let path = "/v1/projects/my-project/secrets"
    let query = [URLQueryItem(name: "$alt", value: "json")]

    // Set up mock handler
    MockURLProtocol.requestHandler = { request in
      #expect(request.httpMethod == "POST")
      #expect(request.url?.path == path)
      #expect(request.url?.query == "$alt=json")

      let response = HTTPURLResponse(
        url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
      let responseData = "{}".data(using: .utf8)!
      return (response, responseData)
    }

    // Configure session with mock protocol
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    let session = URLSession(configuration: config)

    // Use anonymous credentials
    let credentials = Credentials.anonymous()

    let client = try HTTPClient(endpoint: endpoint, credentials: credentials, session: session)

    var request = try await client.Request(path: path, query: query)
    request.httpMethod = "POST"
    request.httpBody = "{}".data(using: .utf8)

    let (data, response) = try await client.data(for: request)

    #expect(response.statusCode == 200)
    #expect(!data.isEmpty)
  }
}
