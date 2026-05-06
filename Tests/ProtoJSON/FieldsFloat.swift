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

@Suite struct FloatFields {
  @Test(
    "float fields deserialize",
    arguments: [
      (#"{}"#, MessageWithF32()),
      (#"{"singular": 0.0            }"#, MessageWithF32()),
      (#"{"singular": 1.5            }"#, MessageWithF32(singular: 1.5)),
      (#"{"singular": "1.5"          }"#, MessageWithF32(singular: 1.5)),
      (#"{"singular": "Infinity"     }"#, MessageWithF32(singular: .infinity)),
      (#"{"singular": "-Infinity"    }"#, MessageWithF32(singular: -.infinity)),
      (#"{"option":   null           }"#, MessageWithF32()),
      (#"{"option":   0.0            }"#, MessageWithF32(option: 0.0)),
      (#"{"option":   1.5            }"#, MessageWithF32(option: 1.5)),
      (#"{"option":   "1.5"          }"#, MessageWithF32(option: 1.5)),
      (#"{"repeated": []             }"#, MessageWithF32()),
      (#"{"repeated": [0.0]          }"#, MessageWithF32(repeated: [0.0])),
      (#"{"repeated": [1.5, -2.0]    }"#, MessageWithF32(repeated: [1.5, -2.0])),
      (#"{"repeated": ["1.5", "-2.0"]}"#, MessageWithF32(repeated: [1.5, -2.0])),
      (#"{"map":      {}             }"#, MessageWithF32()),
      (#"{"map":      {"a": 1.5}     }"#, MessageWithF32(map: ["a": 1.5])),
      (#"{"map":      {"a": "1.5"}   }"#, MessageWithF32(map: ["a": 1.5])),
    ])
  func deserialize(input: String, want: MessageWithF32) throws {
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithF32.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }

  // Cannot use == with NaN, so we must some complicated predicates.
  @Test(
    "float fields deserialize NaN",
    arguments: [
      (
        #"{"singular": "NaN"        }"#,
        { @Sendable (got: MessageWithF32) -> Float32? in .some(got.singular) }
      ),
      (
        #"{"option":   "NaN"        }"#,
        { @Sendable (got: MessageWithF32) -> Float32? in got.option }
      ),
      (
        #"{"repeated": ["NaN"]      }"#,
        { @Sendable (got: MessageWithF32) -> Float32? in got.repeated.first }
      ),
      (
        #"{"map":      {"a": "NaN"} }"#,
        { @Sendable (got: MessageWithF32) -> Float32? in got.map["a"] }
      ),
    ]
  ) func deserializeNaN(input: String, value: @Sendable (MessageWithF32) -> Float32?) throws {
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithF32.self, from: input.data(using: .utf8)!)
    #expect(value(got).map({ $0.isNaN }) ?? false, "got=\(got)")
  }
}
