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

@testable import GoogleCloudGax

@Suite struct ProtoJSONDecoderTest {
  @Test(
    "decode optionals",
    arguments: [
      (#"{}"#, MessageWithOptionals()),
      (#"{"fieldBool":   null }"#, MessageWithOptionals()),
      (#"{"fieldString": null }"#, MessageWithOptionals()),
      (#"{"fieldInt":    null }"#, MessageWithOptionals()),
      (#"{"fieldUInt":   null }"#, MessageWithOptionals()),
      (#"{"fieldInt32":  null }"#, MessageWithOptionals()),
      (#"{"fieldUInt32": null }"#, MessageWithOptionals()),
      (#"{"fieldInt64":  null }"#, MessageWithOptionals()),
      (#"{"fieldUInt64": null }"#, MessageWithOptionals()),
      (#"{"fieldFloat":  null }"#, MessageWithOptionals()),
      (#"{"fieldDouble": null }"#, MessageWithOptionals()),
      (#"{"message":     null }"#, MessageWithOptionals()),
      (#"{"fieldBool":   true }"#, MessageWithOptionals().with { $0.fieldBool = true }),
      (#"{"fieldString": "42" }"#, MessageWithOptionals().with { $0.fieldString = "42" }),
      (#"{"fieldInt":    42   }"#, MessageWithOptionals().with { $0.fieldInt = 42 }),
      (#"{"fieldUInt":   42   }"#, MessageWithOptionals().with { $0.fieldUInt = 42 }),
      (#"{"fieldInt32":  42   }"#, MessageWithOptionals().with { $0.fieldInt32 = 42 }),
      (#"{"fieldUInt32": 42   }"#, MessageWithOptionals().with { $0.fieldUInt32 = 42 }),
      (#"{"fieldInt64":  42   }"#, MessageWithOptionals().with { $0.fieldInt64 = 42 }),
      (#"{"fieldUInt64": 42   }"#, MessageWithOptionals().with { $0.fieldUInt64 = 42 }),
      (#"{"fieldFloat":  42   }"#, MessageWithOptionals().with { $0.fieldFloat = 42 }),
      (#"{"fieldDouble": 42   }"#, MessageWithOptionals().with { $0.fieldDouble = 42 }),
      (#"{"message":     {}   }"#, MessageWithOptionals().with { $0.message = MessageWithMap() }),
    ])
  func decodeOptionals(input: String, want: MessageWithOptionals) throws {
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithOptionals.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }

  @Test func decodeMissingMap() throws {
    let input = "{}"
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithMap.self, from: input.data(using: .utf8)!)
    #expect(got == MessageWithMap())
  }

  @Test func decodeMissingRepeated() throws {
    let input = "{}"
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithRepeated.self, from: input.data(using: .utf8)!)
    #expect(got == MessageWithRepeated())
  }

  @Test func decodeMissingMapNested() throws {
    let input = """
      {
        "repeatedMessage":[
          {"stringField": "abc"},
          {"stringField": "cde"}
        ]
      }
      """
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithRepeated.self, from: input.data(using: .utf8)!)
    let want = MessageWithRepeated(
      repeatedMessage: [
        MessageWithMap(stringField: "abc", mapField: [:]),
        MessageWithMap(stringField: "cde", mapField: [:]),
      ])
    #expect(got == want)
  }

  @Test func decodeMissingScalars() throws {
    let input = "{}"
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithScalars.self, from: input.data(using: .utf8)!)
    #expect(got == MessageWithScalars())
  }

  // Only test the types that appear in sidekick messages. `Int` and `UInt` may be used with enums.
  struct MessageWithOptionals: Decodable, Equatable {
    var fieldBool: Bool? = nil
    var fieldString: String? = nil
    var fieldInt: Int? = nil
    var fieldUInt: UInt? = nil
    var fieldInt32: Int32? = nil
    var fieldUInt32: UInt32? = nil
    var fieldInt64: Int64? = nil
    var fieldUInt64: UInt64? = nil
    var fieldFloat: Float? = nil
    var fieldDouble: Double? = nil
    var message: MessageWithMap? = nil

    func with(_ config: (inout Self) -> Void) -> Self {
      var copy = self
      config(&copy)
      return copy
    }
  }

  struct MessageWithMap: Decodable, Equatable {
    var stringField: String = String()
    var mapField: [String: String] = [:]
  }
  struct MessageWithRepeated: Decodable, Equatable {
    var repeatedMessage: [MessageWithMap] = []
    var repeatedString: [String] = []
    var repeatedData: [Data] = []
    var repeatedNested: [MessageWithScalars] = []
  }
  struct MessageWithScalars: Decodable, Equatable {
    var stringField: String = String()
    var dataField: Data = Data()
    var intField: Int64 = Int64()
    var boolField: Bool = false
  }
}
