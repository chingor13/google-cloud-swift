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

@Suite struct FieldsListValue {
  @Test(
    "ListValue fields deserialize",
    arguments: [
      (#"{}"#, MessageWithListValue()),
      (#"{"singular": null         }"#, MessageWithListValue()),
      (#"{"singular": []           }"#, MessageWithListValue(singular: [])),
      (#"{"singular": [42]         }"#, MessageWithListValue(singular: [.number(42)])),
      (#"{"singular": ["hello"]    }"#, MessageWithListValue(singular: [.string("hello")])),
      (
        #"{"singular": [42, "hello"]}"#,
        MessageWithListValue(singular: [.number(42), .string("hello")])
      ),
      (#"{"optional": [42]         }"#, MessageWithListValue(optional: [.number(42)])),
      (#"{"repeated": []           }"#, MessageWithListValue()),
      (#"{"repeated": [[42]]       }"#, MessageWithListValue(repeated: [[.number(42)]])),
      (#"{"map":      {}           }"#, MessageWithListValue()),
      (#"{"map":      {"a": [42] } }"#, MessageWithListValue(map: ["a": [.number(42)]])),
    ])
  func deserialize(input: String, want: MessageWithListValue) throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithListValue.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
