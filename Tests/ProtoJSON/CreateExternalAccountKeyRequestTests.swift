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

@Suite struct CreateExternalAccountKeyRequestTests {
  @Test func testJSONSerialization() throws {
    let key = ExternalAccountKey(
      name: "test-only-name",
      keyId: "my-key-id",
      b64MacKey: "my-secret-key".data(using: .utf8)!
    )
    let request = CreateExternalAccountKeyRequest(
      parent: "projects/my-project/locations/global",
      externalAccountKey: key
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(request)

    let jsonString = String(data: data, encoding: .utf8)
    #expect(jsonString != nil)

    let expectedSecretBase64 = "my-secret-key".data(using: .utf8)!.base64EncodedString()

    let expectedJSON =
      #"{"externalAccountKey":{"b64MacKey":"\#(expectedSecretBase64)","keyId":"my-key-id","name":"test-only-name"},"parent":"projects/my-project/locations/global"}"#

    #expect(jsonString == expectedJSON)
  }

  @Test func testJSONDeserialization() throws {
    let expectedSecretBase64 = "my-secret-key".data(using: .utf8)!.base64EncodedString()
    let jsonString =
      #"{"externalAccountKey":{"b64MacKey":"\#(expectedSecretBase64)","keyId":"my-key-id","name":"test-only-name"},"parent":"projects/my-project/locations/global"}"#
    let data = jsonString.data(using: .utf8)!

    let decoder = JSONDecoder()
    let request = try decoder.decode(CreateExternalAccountKeyRequest.self, from: data)

    #expect(request.parent == "projects/my-project/locations/global")
    let key = try #require(request.externalAccountKey)
    #expect(key.name == "test-only-name")
    #expect(key.keyId == "my-key-id")
    #expect(key.b64MacKey == "my-secret-key".data(using: .utf8)!)
  }

  @Test func testJSONSerialization_NilKey() throws {
    let request = CreateExternalAccountKeyRequest(
      parent: "projects/my-project/locations/global",
      externalAccountKey: nil
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(request)

    let jsonString = String(data: data, encoding: .utf8)
    #expect(jsonString != nil)

    let expectedJSON = #"{"parent":"projects/my-project/locations/global"}"#

    #expect(jsonString == expectedJSON)
  }

  @Test func testJSONDeserialization_NilKey() throws {
    let jsonString = #"{"parent":"projects/my-project/locations/global"}"#
    let data = jsonString.data(using: .utf8)!

    let decoder = JSONDecoder()
    let request = try decoder.decode(CreateExternalAccountKeyRequest.self, from: data)

    #expect(request.parent == "projects/my-project/locations/global")
    #expect(request.externalAccountKey == nil)
  }
}
