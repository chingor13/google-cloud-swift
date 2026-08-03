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

@testable import GoogleCloudGax
import GoogleRpc
import NIOCore
import NIOHTTP1
import NIOPosix
import NIOTestUtils
import Testing

@Suite(.serialized) struct HttpClientTest {
  @Test(arguments: [
    // A `?` in the path results in a percent-encoded `?` == %3F
    ("/path?$name=value", "path%3F$name=value"),
    // A percent-encoded `?` in the path results in a percent-encoded `%` == %25
    ("/path%3F$name=value", "path%253F$name=value"),
  ]) func escapePath(
    inputPath: String, wantPath: String
  ) async throws {
    let endpoint = "http://localhost:1234"
    let credentials = try Credentials(configuration: .anonymous)
    let options = ClientOptions().with { $0.credentials = credentials }
    let client = try HTTPClient(from: options, withDefaultEndpoint: endpoint)
    let query = [URLQueryItem(name: "$alt", value: "json")]
    let request = try await client.Request(path: inputPath, query: query)
    // Note the percent-escaped `?`
    #expect(
      request.url == "http://localhost:1234/\(wantPath)?$alt=json")
  }

  @Test(arguments: [
    "bad-bad-bad",
    "htt://localhost:1",
    "file:///etc/passwd",
    "http:///",
    "https:///",
  ]) func badEndpoint(input: String) throws {
    let credentials = try Credentials(configuration: .anonymous)
    let options = ClientOptions().with {
      $0.credentials = credentials
      $0.endpoint = input
    }
    let error = #expect(throws: ClientError.self) {
      let client = try HTTPClient(from: options, withDefaultEndpoint: "https://localhost:1234")
      print("client=\(client)")
    }
    guard case let .invalidEndpoint(msg) = error else {
      Issue.record("Mismatched error type, want .invalidEndpoint, got=\(error).")
      return
    }
    #expect(msg.contains(input), "error=\(error)")
  }

  @Test(arguments: [
    "bad-bad-bad",
    "htt://localhost:1",
    "file:///etc/passwd",
    "http:///",
    "https:///",
  ]) func badDefaultEndpoint(input: String) throws {
    let credentials = try Credentials(configuration: .anonymous)
    let options = ClientOptions().with {
      $0.credentials = credentials
    }
    let error = #expect(throws: ClientError.self) {
      let _ = try HTTPClient(from: options, withDefaultEndpoint: input)
    }
    guard case let .invalidEndpoint(msg) = error else {
      Issue.record("Mismatched error type, want .invalidEndpoint, got=\(error).")
      return
    }
    #expect(msg.contains(input), "error=\(error)")
  }

  @Test func postRequest() async throws {
    let server = NIOHTTP1TestServer(group: MultiThreadedEventLoopGroup.singleton)
    defer { try! server.stop() }

    let endpoint = "http://localhost:\(server.serverPort)"
    let path = "/v1/projects/my-project/secrets"
    let query = [URLQueryItem(name: "$alt", value: "json")]

    let options = ClientOptions().with {
      $0.endpoint = endpoint
      $0.credentials = try! Credentials(configuration: .anonymous)
    }
    let client = try HTTPClient(from: options, withDefaultEndpoint: endpoint)

    var request = try await client.Request(path: path, query: query)
    request.method = .POST
    request.body = .bytes(Data("{}".utf8))

    async let clientTask = client.data(for: request)

    let requestHead = try server.readInbound()
    guard case .head(let head) = requestHead else {
      Issue.record("Expected head, got \(requestHead)")
      return
    }
    #expect(head.method == .POST)
    #expect(head.uri == "\(path)?$alt=json")

    let requestBody = try server.readInbound()
    guard case .body(let buffer) = requestBody else {
      Issue.record("Expected body, got \(requestBody)")
      return
    }
    #expect(String(buffer: buffer) == "{}")

    let requestEnd = try server.readInbound()
    guard case .end = requestEnd else {
      Issue.record("Expected end, got \(requestEnd)")
      return
    }

    try server.writeOutbound(
      .head(
        HTTPResponseHead(
          version: .http1_1, status: .ok, headers: ["Content-Type": "application/json"])))
    try server.writeOutbound(.body(.byteBuffer(ByteBuffer(string: "{}"))))
    try server.writeOutbound(.end(nil))

    let (data, response) = try await clientTask

    #expect(response.statusCode == 200)
    #expect(!data.isEmpty)
  }

  @Test func getErrorDetails() async throws {
    let server = NIOHTTP1TestServer(group: MultiThreadedEventLoopGroup.singleton)
    defer { try! server.stop() }

    let endpoint = "http://localhost:\(server.serverPort)"
    let path = "/v1/projects/test-only-project/locations/us-central1/orchestrationClusters"
    let query = [URLQueryItem(name: "$alt", value: "json")]

    let options = ClientOptions().with {
      $0.endpoint = endpoint
      $0.credentials = try! Credentials(configuration: .anonymous)
    }
    let client = try HTTPClient(from: options, withDefaultEndpoint: endpoint)

    var request = try await client.Request(path: path, query: query)
    request.method = .GET

    async let clientTask = client.rpc(for: request)

    let requestHead = try server.readInbound()
    guard case .head(let head) = requestHead else {
      Issue.record("Expected head, got \(requestHead)")
      return
    }
    #expect(head.method == .GET)
    #expect(head.uri == "\(path)?$alt=json")

    let requestEnd = try server.readInbound()
    guard case .end = requestEnd else {
      Issue.record("Expected end, got \(requestEnd)")
      return
    }

    try server.writeOutbound(
      .head(
        HTTPResponseHead(
          version: .http1_1, status: .forbidden,
          headers: ["Content-Type": "application/json; charset=UTF-8"])))
    try server.writeOutbound(.body(.byteBuffer(ByteBuffer(string: errorResponseWithDetails))))
    try server.writeOutbound(.end(nil))

    let response = await clientTask
    guard case let .failure(.service(serviceError)) = response else {
      Issue.record("expected an service error response, got=\(response)")
      return
    }
    #expect(serviceError.code == Code.permissionDenied, "\(serviceError)")
    #expect(serviceError.message.starts(with: "Telco Automation API"), "\(serviceError)")
    #expect(serviceError.details == wantDetails, "\(serviceError)")
  }

  @Test func getHttpError() async throws {
    let server = NIOHTTP1TestServer(group: MultiThreadedEventLoopGroup.singleton)
    defer { try! server.stop() }

    let endpoint = "http://localhost:\(server.serverPort)"
    let path = "/v1/projects//locations/us-central1/orchestrationClusters"
    let query = [URLQueryItem(name: "$alt", value: "json")]

    let options = ClientOptions().with {
      $0.endpoint = endpoint
      $0.credentials = try! Credentials(configuration: .anonymous)
    }
    let client = try HTTPClient(from: options, withDefaultEndpoint: endpoint)

    var request = try await client.Request(path: path, query: query)
    request.method = .GET

    async let clientTask = client.rpc(for: request)

    let requestHead = try server.readInbound()
    guard case .head(let head) = requestHead else {
      Issue.record("Expected head, got \(requestHead)")
      return
    }
    #expect(head.method == .GET)
    #expect(head.uri == "\(path)?$alt=json")

    let requestEnd = try server.readInbound()
    guard case .end = requestEnd else {
      Issue.record("Expected end, got \(requestEnd)")
      return
    }

    try server.writeOutbound(
      .head(
        HTTPResponseHead(
          version: .http1_1, status: .notFound,
          headers: ["Content-Type": "text/html; charset=UTF-8"])))
    try server.writeOutbound(
      .body(
        .byteBuffer(
          ByteBuffer(string: "<!DOCTYPE html><html lang=en><title>Error 404</title></html>"))))
    try server.writeOutbound(.end(nil))

    let response = await clientTask
    guard case let .failure(.http(httpError)) = response else {
      Issue.record("expected an http error response, got=\(response)")
      return
    }
    #expect(httpError.http_status_code == 404)
  }
}

let errorResponseWithDetails = """
  {
    "error": {
      "code": 403,
      "message": "Telco Automation API has not been used in project test-only-project before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/telcoautomation.googleapis.com/overview?project=test-only-project then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry.",
      "status": "PERMISSION_DENIED",
      "details": [
        {
          "@type": "type.googleapis.com/google.rpc.ErrorInfo",
          "reason": "SERVICE_DISABLED",
          "domain": "googleapis.com",
          "metadata": {
            "activationUrl": "https://console.developers.google.com/apis/api/telcoautomation.googleapis.com/overview?project=test-only-project",
            "service": "telcoautomation.googleapis.com",
            "consumer": "projects/test-only-project",
            "containerInfo": "test-only-project",
            "serviceTitle": "Telco Automation API"
          }
        },
        {
          "@type": "type.googleapis.com/google.rpc.LocalizedMessage",
          "locale": "en-US",
          "message": "Telco Automation API has not been used in project test-only-project before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/telcoautomation.googleapis.com/overview?project=test-only-project then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry."
        },
        {
          "@type": "type.googleapis.com/google.rpc.Help",
          "links": [
            {
              "description": "Google developers console API activation",
              "url": "https://console.developers.google.com/apis/api/telcoautomation.googleapis.com/overview?project=test-only-project"
            }
          ]
        }
      ]
    }
  }
  """

let wantDetails: [StatusDetail] = [
  .errorInfo(
    ErrorInfo().with {
      $0.reason = "SERVICE_DISABLED"
      $0.domain = "googleapis.com"
      $0.metadata = [
        "activationUrl":
          "https://console.developers.google.com/apis/api/telcoautomation.googleapis.com/overview?project=test-only-project",
        "service": "telcoautomation.googleapis.com",
        "consumer": "projects/test-only-project",
        "containerInfo": "test-only-project",
        "serviceTitle": "Telco Automation API",
      ]
    }),
  .localizedMessage(
    LocalizedMessage().with {
      $0.locale = "en-US"
      $0.message =
        "Telco Automation API has not been used in project test-only-project before or it is disabled. Enable it by visiting https://console.developers.google.com/apis/api/telcoautomation.googleapis.com/overview?project=test-only-project then retry. If you enabled this API recently, wait a few minutes for the action to propagate to our systems and retry."
    }),
  .help(
    Help().with {
      $0.links = [
        Help.Link().with {
          $0.description = "Google developers console API activation"
          $0.url =
            "https://console.developers.google.com/apis/api/telcoautomation.googleapis.com/overview?project=test-only-project"
        }
      ]
    }),
]
