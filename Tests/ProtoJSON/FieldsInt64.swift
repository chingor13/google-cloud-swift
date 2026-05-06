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

@Suite struct Int64Fields {
  @Test(
    "int64 fields deserialize",
    arguments: [
      (#"{}"#, MessageWithI64()),
      (#"{"singular": 0              }"#, MessageWithI64()),
      (#"{"singular": 42             }"#, MessageWithI64(singular: 42)),
      (#"{"singular": "42"           }"#, MessageWithI64(singular: 42)),
      (#"{"option":   null           }"#, MessageWithI64()),
      (#"{"option":   0              }"#, MessageWithI64(option: 0)),
      (#"{"option":   42             }"#, MessageWithI64(option: 42)),
      (#"{"option":   "42"           }"#, MessageWithI64(option: 42)),
      (#"{"repeated": []             }"#, MessageWithI64()),
      (#"{"repeated": [0]            }"#, MessageWithI64(repeated: [0])),
      (#"{"repeated": [4, 2]         }"#, MessageWithI64(repeated: [4, 2])),
      (#"{"repeated": ["4", "2"]     }"#, MessageWithI64(repeated: [4, 2])),
      // TODO(https://github.com/googleapis/librarian/issues/5808) - support mapKey and mapKeyValue
      (#"{"mapValue": {}             }"#, MessageWithI64()),
      (#"{"mapValue": {"a": 42}      }"#, MessageWithI64(mapValue: ["a": 42])),
      (#"{"mapValue": {"a": "42"}    }"#, MessageWithI64(mapValue: ["a": 42])),
    ])
  func deserialize(input: String, want: MessageWithI64) throws {
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithI64.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
