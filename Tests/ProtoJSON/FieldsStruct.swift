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

@Suite struct FieldsStruct {
  @Test(
    "Struct fields deserialize",
    arguments: [
      (#"{}"#, MessageWithStruct()),
      (#"{"singular": null            }"#, MessageWithStruct()),
      (#"{"singular": {}              }"#, MessageWithStruct().with { $0.singular = [:] }),
      (
        #"{"singular": {"a": 42}       }"#,
        MessageWithStruct().with { $0.singular = ["a": .number(42)] }
      ),
      (
        #"{"singular": {"a": "hello"}  }"#,
        MessageWithStruct().with { $0.singular = ["a": .string("hello")] }
      ),
      (
        #"{"optional": {"a": 42}       }"#,
        MessageWithStruct().with { $0.optional = ["a": .number(42)] }
      ),
      (#"{"repeated": []              }"#, MessageWithStruct()),
      (#"{"repeated": [{}]            }"#, MessageWithStruct().with { $0.repeated = [[:]] }),
      (
        #"{"repeated": [{"a": 42}]     }"#,
        MessageWithStruct().with { $0.repeated = [["a": .number(42)]] }
      ),
      (#"{"map":      {}              }"#, MessageWithStruct()),
      (
        #"{"map":      {"a": {"b": 42}}}"#,
        MessageWithStruct().with { $0.map = ["a": ["b": .number(42)]] }
      ),
    ])
  func deserialize(input: String, want: MessageWithStruct) throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithStruct.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
