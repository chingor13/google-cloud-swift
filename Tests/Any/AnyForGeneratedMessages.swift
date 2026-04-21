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
import GoogleCloudWkt
import Testing

// Verify `Any` can be used with a struct defined outside the `GoogleCloudWkt`  package.
//
// Eventually `TestMessage` will be replaced with a generated message. We use an integration test to
// avoid a cyclic dependency between the `GoogleCloudWkt` package and the generated library.

struct WrappedAny: Codable {
  let value: GoogleCloudWkt.`Any`
}

@Test("Any decoding TestMessage")
func testDecodingMessage() throws {
  let jsonString =
    #"{"value":{"@type":"type.googleapis.com/test.TestMessage","keyId":"test-key-id","name":"test-name","someNumber":42}}"#
  let data = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()
  let wrapped = try decoder.decode(WrappedAny.self, from: data)
  let any = wrapped.value
  #expect(any.typeUrl == "type.googleapis.com/test.TestMessage")

  let got = try TestMessage(fromAny: any)
  let want = TestMessage(name: "test-name", keyId: "test-key-id", someNumber: 42)
  #expect(got == want)
}

@Test("Any encoding TestMessage")
func testEncodingMessage() throws {
  let input = TestMessage(name: "test-name", keyId: "test-key-id", someNumber: 42)
  let any = try `Any`(fromMessage: input)
  let wrapped = WrappedAny(value: any)
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
  let data = try encoder.encode(wrapped)
  let got = String(data: data, encoding: .utf8)!

  let want =
    #"{"value":{"@type":"type.googleapis.com/test.TestMessage","keyId":"test-key-id","name":"test-name","someNumber":42}}"#
  #expect(got == want)
}

/// A synthetic test message.
///
/// The idea is to validate the code with this message. Eventually we will
/// modify the generator to generate the extension / protocol definitions.
/// and then we can test with a real message.
public struct TestMessage: Codable, Equatable {
  public var name: String
  public var keyId: String
  public var someNumber: Int32

  public init(
    name: String = String(),
    keyId: String = String(),
    someNumber: Int32 = Int32(),
  ) {
    self.name = name
    self.keyId = keyId
    self.someNumber = someNumber
  }
}

extension TestMessage: GoogleCloudWkt._AnyPackable {
  public static var _anyTypeUrl: String { get { return "type.googleapis.com/test.TestMessage" } }

  public init(fromAny any: GoogleCloudWkt.`Any`) throws {
    self = try GoogleCloudWkt._slowAnyDeserialize(Self.self, from: any)
  }

  public func _pack() throws -> Struct {
    return try GoogleCloudWkt._slowAnySerialize(message: self)
  }
}
