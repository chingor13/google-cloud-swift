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
import Testing

#if IntegrationTests

  @Test func authHeaders() async throws {
    let credentials = try Credentials()
    let headers = try await credentials.headers()

    #expect(!headers.isEmpty)

    // Convert to dictionary for easy lookup
    let headerDict = Dictionary(uniqueKeysWithValues: headers)
    let authValue = try #require(headerDict["Authorization"])
    #expect(authValue.hasPrefix("Bearer "))
  }

  @Test func listSecretsWithAuth() async throws {
    let projectId = try #require(
      ProcessInfo.processInfo.environment["GOOGLE_CLOUD_PROJECT"],
      "GOOGLE_CLOUD_PROJECT environment variable must be set")

    let url = URL(
      string: "https://secretmanager.googleapis.com/v1/projects/\(projectId)/secrets")!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    // Initialize credentials and inject headers
    let credentials = try Credentials()
    let headers = try await credentials.headers()
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }

    // Execute the authenticated request
    let (data, response) = try await URLSession.shared.data(for: request)
    let httpResponse = try #require(response as? HTTPURLResponse)

    // We expect this to succeed with authentication (200 OK)
    #expect(
      httpResponse.statusCode == 200,
      "Expected 200 OK with auth, but got \(httpResponse.statusCode)")

    // Parse the success response
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

    // The response should be a JSON object, possibly with a 'secrets' array if there are any
    // or simply an empty object if no secrets exist, but the request itself should succeed.
    #expect(json != nil)
  }
#endif
