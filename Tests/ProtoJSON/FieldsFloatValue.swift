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

@Suite struct FieldsFloatValue {
  @Test(
    "FloatValue fields deserialize",
    arguments: [
      (#"{}"#, MessageWithFloatValue()),
      (#"{"singular": null         }"#, MessageWithFloatValue()),
      (#"{"singular": 4.2          }"#, MessageWithFloatValue().with { $0.singular = 4.2 }),
      (#"{"singular": "4.2"        }"#, MessageWithFloatValue().with { $0.singular = 4.2 }),
      (#"{"repeated": []           }"#, MessageWithFloatValue()),
      (#"{"repeated": [4.2]        }"#, MessageWithFloatValue().with { $0.repeated = [4.2] }),
      (#"{"map":      {}           }"#, MessageWithFloatValue()),
      (#"{"map":      {"a": 4.2 }  }"#, MessageWithFloatValue().with { $0.map = ["a": 4.2] }),
    ])
  func deserialize(input: String, want: MessageWithFloatValue) throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithFloatValue.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
