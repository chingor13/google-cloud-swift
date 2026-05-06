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

@Suite struct FieldsInt64Value {
  @Test(
    "Int64Value fields deserialize",
    arguments: [
      (#"{}"#, MessageWithInt64Value()),
      (#"{"singular": null         }"#, MessageWithInt64Value()),
      (#"{"singular": 42           }"#, MessageWithInt64Value(singular: 42)),
      (#"{"singular": "42"         }"#, MessageWithInt64Value(singular: 42)),
      (#"{"repeated": []           }"#, MessageWithInt64Value()),
      (#"{"repeated": [42]         }"#, MessageWithInt64Value(repeated: [42])),
      (#"{"map":      {}           }"#, MessageWithInt64Value()),
      (#"{"map":      {"a": 42 }   }"#, MessageWithInt64Value(map: ["a": 42])),
    ])
  func deserialize(input: String, want: MessageWithInt64Value) throws {
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithInt64Value.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
