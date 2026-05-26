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
import GoogleCloudWkt

@Suite struct FieldsEnum {
  @Test(
    "Enum fields deserialize",
    arguments: [
      (#"{}"#, MessageWithEnum()),
      (#"{"singular": 0}"#, MessageWithEnum(singular: .unspecified)),
      (#"{"singular": 1}"#, MessageWithEnum(singular: .red)),
      (#"{"optional": 2}"#, MessageWithEnum(optional: .green)),
      (#"{"optional": null}"#, MessageWithEnum()),
      (#"{"repeated": [1, 3]}"#, MessageWithEnum(repeated: [.red, .blue])),
      (#"{"map": {"a": 2}}"#, MessageWithEnum(map: ["a": .green])),
    ])
  func deserialize(input: String, want: MessageWithEnum) throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithEnum.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }

  @Test("Use enum with @unknown")
  func useEnum() throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithEnum.self, from: "{}".data(using: .utf8)!)
    #expect(got.singular == .unspecified)
    switch got.singular {
    case .unspecified:
      #expect(Bool(true), "\(got)")
    case .red, .green, .blue:
      #expect(Bool(false), "\(got)")
    @unknown default:
      #expect(Bool(true), "\(got)")
    }
  }
}
