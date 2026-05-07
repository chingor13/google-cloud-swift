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

import GoogleCloudGax
import GoogleCloudWkt

@Suite struct FieldsValue {
  @Test(
    "Value fields deserialize",
    arguments: [
      (#"{}"#, MessageWithValue()),
      (#"{"singular": null         }"#, MessageWithValue()),
      (#"{"singular": 42           }"#, MessageWithValue(singular: .number(42))),
      (#"{"singular": "hello"      }"#, MessageWithValue(singular: .string("hello"))),
      (#"{"singular": true         }"#, MessageWithValue(singular: .bool(true))),
      (#"{"singular": {}           }"#, MessageWithValue(singular: .object([:]))),
      (#"{"singular": []           }"#, MessageWithValue(singular: .array([]))),
      (#"{"optional": 42           }"#, MessageWithValue(optional: .number(42))),
      (#"{"repeated": []           }"#, MessageWithValue()),
      (#"{"repeated": [null]       }"#, MessageWithValue(repeated: [.null(NullValue())])),
      (
        #"{"repeated": [42, "hello"]}"#,
        MessageWithValue(repeated: [.number(42), .string("hello")])
      ),
      (#"{"map":      {}           }"#, MessageWithValue()),
      (#"{"map":      {"a": 42}    }"#, MessageWithValue(map: ["a": .number(42)])),
      (#"{"map":      {"a": null}  }"#, MessageWithValue(map: ["a": .null(NullValue())])),
    ])
  func deserialize(input: String, want: MessageWithValue) throws {
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithValue.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
