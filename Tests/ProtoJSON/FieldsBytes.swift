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

@Suite struct BytesFields {
  @Test(
    "bytes fields deserialize",
    arguments: [
      (#"{}"#, MessageWithBytes()),
      (#"{"singular": ""            }"#, MessageWithBytes()),
      (#"{"singular": "NDI="        }"#, MessageWithBytes(singular: Data("42".utf8))),
      (#"{"option":   null          }"#, MessageWithBytes()),
      (#"{"option":   ""            }"#, MessageWithBytes(option: Data())),
      (#"{"option":   "NDI="        }"#, MessageWithBytes(option: Data("42".utf8))),
      (#"{"repeated": []            }"#, MessageWithBytes()),
      (#"{"repeated": ["NDI="]      }"#, MessageWithBytes(repeated: [Data("42".utf8)])),
      (#"{"repeated": ["NDI=", ""]  }"#, MessageWithBytes(repeated: [Data("42".utf8), Data()])),
      (#"{"map":      {}            }"#, MessageWithBytes()),
      (#"{"map":      {"a": "NDI="} }"#, MessageWithBytes(map: ["a": Data("42".utf8)])),
    ])
  func deserialize(input: String, want: MessageWithBytes) throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithBytes.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
