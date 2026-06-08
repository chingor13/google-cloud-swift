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

@Suite struct StringFields {
  @Test(
    "string fields deserialize",
    arguments: [
      (#"{}"#, MessageWithString()),
      (#"{"singular": ""            }"#, MessageWithString()),
      (#"{"singular": "42"          }"#, MessageWithString().with { $0.singular = "42" }),
      (#"{"option":   null          }"#, MessageWithString()),
      (#"{"option":   ""            }"#, MessageWithString().with { $0.option = "" }),
      (#"{"option":   "42"          }"#, MessageWithString().with { $0.option = "42" }),
      (#"{"repeated": []            }"#, MessageWithString()),
      (#"{"repeated": [""]          }"#, MessageWithString().with { $0.repeated = [""] }),
      (#"{"repeated": ["4", "2"]    }"#, MessageWithString().with { $0.repeated = ["4", "2"] }),
      // TODO(https://github.com/googleapis/librarian/issues/5808) - support mapValue
      (#"{"mapKey": {}              }"#, MessageWithString()),
      (#"{"mapKey": {"4": 2}        }"#, MessageWithString().with { $0.mapKey = ["4": 2] }),
      (#"{"mapKey": {"4": "2"}      }"#, MessageWithString().with { $0.mapKey = ["4": 2] }),
      (#"{"mapKeyValue": {}         }"#, MessageWithString()),
      (#"{"mapKeyValue": {"4": "2"} }"#, MessageWithString().with { $0.mapKeyValue = ["4": "2"] }),
    ])
  func deserialize(input: String, want: MessageWithString) throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithString.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
