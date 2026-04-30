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
