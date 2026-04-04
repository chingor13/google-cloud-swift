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
import Testing

@testable import GoogleCloudSecurityPublicCaV1

@Suite struct ExternalAccountKeyTests {
  @Test func testJSONSerialization() throws {
    let key = ExternalAccountKey(
      name: "test-only-name",
      keyID: "my-key-id",
      b64MacKey: "my-secret-key".data(using: .utf8)!
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]  // For predictable output
    let data = try encoder.encode(key)

    let jsonString = String(data: data, encoding: .utf8)
    #expect(jsonString != nil)

    // Verify the JSON content
    // Default Codable for Data is base64 string
    let expectedSecretBase64 = "my-secret-key".data(using: .utf8)!.base64EncodedString()

    // JSONEncoder escapes slashes by default
    let expectedJSON =
      #"{"b64MacKey":"\#(expectedSecretBase64)","keyID":"my-key-id","name":"test-only-name"}"#

    #expect(jsonString == expectedJSON)
  }

  @Test func testJSONDeserialization() throws {
    let expectedSecretBase64 = "my-secret-key".data(using: .utf8)!.base64EncodedString()
    let jsonString =
      #"{"b64MacKey":"\#(expectedSecretBase64)","keyID":"my-key-id","name":"test-only-name"}"#
    let data = jsonString.data(using: .utf8)!

    let decoder = JSONDecoder()
    let key = try decoder.decode(ExternalAccountKey.self, from: data)

    #expect(key.name == "test-only-name")
    #expect(key.keyID == "my-key-id")
    #expect(key.b64MacKey == "my-secret-key".data(using: .utf8)!)
  }
}
