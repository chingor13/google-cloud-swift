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
import GoogleCloudWkt

@Suite struct FieldsFieldMask {
  @Test(
    "FieldMask fields deserialize",
    arguments: [
      (#"{}"#, MessageWithFieldMask()),
      (
        #"{"singular": "userDisplayName,photo"}"#,
        MessageWithFieldMask(
          singular: GoogleCloudWkt.FieldMask(paths: ["user_display_name", "photo"]))
      ),
      (
        #"{"optional": "userDisplayName,photo"}"#,
        MessageWithFieldMask(
          optional: GoogleCloudWkt.FieldMask(paths: ["user_display_name", "photo"]))
      ),
      (#"{"repeated": []}"#, MessageWithFieldMask()),
      (
        #"{"repeated": ["userDisplayName,photo"]}"#,
        MessageWithFieldMask(repeated: [
          GoogleCloudWkt.FieldMask(paths: ["user_display_name", "photo"])
        ])
      ),
      (
        #"{"map":      {"a": "userDisplayName,photo"}}"#,
        MessageWithFieldMask(map: [
          "a": GoogleCloudWkt.FieldMask(paths: ["user_display_name", "photo"])
        ])
      ),
    ])
  func deserialize(input: String, want: MessageWithFieldMask) throws {
    let decoder = ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithFieldMask.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }
}
