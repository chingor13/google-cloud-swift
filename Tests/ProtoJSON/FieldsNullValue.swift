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

@Suite struct FieldsNullValue {
  @Test(
    "NullValue fields deserialize",
    arguments: [
      (#"{                        }"#, MessageWithNullValue()),
      (#"{"singular": null        }"#, MessageWithNullValue()),
      (#"{"optional": null        }"#, MessageWithNullValue()),
      (#"{"repeated": []          }"#, MessageWithNullValue()),
      (#"{"repeated": [null]      }"#, MessageWithNullValue().with { $0.repeated = [NullValue()] }),
      (#"{"map":      {}          }"#, MessageWithNullValue()),
      (#"{"map":      {"a": null} }"#, MessageWithNullValue().with { $0.map = ["a": NullValue()] }),
    ])
  func deserialize(input: String, want: MessageWithNullValue) throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithNullValue.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
