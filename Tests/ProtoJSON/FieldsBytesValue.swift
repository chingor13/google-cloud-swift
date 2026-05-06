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

@Suite struct FieldsBytesValue {
  @Test(
    "BytesValue fields deserialize",
    arguments: [
      (#"{}"#, MessageWithBytesValue()),
      (#"{"singular": "NDI="         }"#, MessageWithBytesValue(singular: Data("42".utf8))),
      (#"{"repeated": []             }"#, MessageWithBytesValue()),
      (#"{"repeated": ["NDI="]       }"#, MessageWithBytesValue(repeated: [Data("42".utf8)])),
      (#"{"map":      {}             }"#, MessageWithBytesValue()),
      (#"{"map":      {"a": "NDI=" } }"#, MessageWithBytesValue(map: ["a": Data("42".utf8)])),
    ])
  func deserialize(input: String, want: MessageWithBytesValue) throws {
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithBytesValue.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
