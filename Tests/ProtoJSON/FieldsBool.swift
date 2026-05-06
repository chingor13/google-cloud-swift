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

@Suite struct BoolFields {
  @Test(
    "bool fields deserialize",
    arguments: [
      (#"{}"#, MessageWithBool()),
      (#"{"singular": false         }"#, MessageWithBool()),
      (#"{"singular": true          }"#, MessageWithBool(singular: true)),
      (#"{"option":   null          }"#, MessageWithBool()),
      (#"{"option":   false         }"#, MessageWithBool(option: false)),
      (#"{"option":   true          }"#, MessageWithBool(option: true)),
      (#"{"repeated": []            }"#, MessageWithBool()),
      (#"{"repeated": [false]       }"#, MessageWithBool(repeated: [false])),
      (#"{"repeated": [true, false] }"#, MessageWithBool(repeated: [true, false])),
      // TODO(https://github.com/googleapis/librarian/issues/5808) - support mapKey and mapKeyValue
      (#"{"mapValue": {}            }"#, MessageWithBool()),
      (#"{"mapValue": {"a": true}   }"#, MessageWithBool(mapValue: ["a": true])),
      (#"{"mapValue": {"a": "true"} }"#, MessageWithBool(mapValue: ["a": true])),
    ])
  func deserialize(input: String, want: MessageWithBool) throws {
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithBool.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
