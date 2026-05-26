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

@Suite struct FieldsRecursion {
  @Test(
    "Recursion fields deserialize",
    arguments: [
      // Empty case
      (#"{}"#, MessageWithRecursion()),
      // Deep recursive chain
      (
        """
        {
          "singular": {
            "level1": {
              "recurse": {
                "singular": {
                  "side": {
                    "value": "depth-3"
                  }
                }
              }
            }
          }
        }
        """,
        MessageWithRecursion(
          singular: MessageWithRecursion.Level0(
            level1: MessageWithRecursion.Level1(
              recurse: MessageWithRecursion(
                singular: MessageWithRecursion.Level0(
                  side: MessageWithRecursion.NonRecursive(value: "depth-3")
                )
              )
            )
          )
        )
      ),
      // Optional recursive field
      (
        #"{"optional": {"side": {"value": "optional-side"}}}"#,
        MessageWithRecursion(
          optional: MessageWithRecursion.Level0(
            side: MessageWithRecursion.NonRecursive(value: "optional-side")
          )
        )
      ),
      // Repeated recursive field
      (
        #"{"repeated": [{"side": {"value": "side-1"}}, {"side": {"value": "side-2"}}]}"#,
        MessageWithRecursion(
          repeated: [
            MessageWithRecursion.Level0(side: MessageWithRecursion.NonRecursive(value: "side-1")),
            MessageWithRecursion.Level0(side: MessageWithRecursion.NonRecursive(value: "side-2")),
          ]
        )
      ),
      // Map recursive field
      (
        #"{"map": {"key1": {"side": {"value": "side-1"}}, "key2": {"side": {"value": "side-2"}}}}"#,
        MessageWithRecursion(
          map: [
            "key1": MessageWithRecursion.Level0(
              side: MessageWithRecursion.NonRecursive(value: "side-1")
            ),
            "key2": MessageWithRecursion.Level0(
              side: MessageWithRecursion.NonRecursive(value: "side-2")
            ),
          ]
        )
      ),
    ])
  func deserialize(input: String, want: MessageWithRecursion) throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(MessageWithRecursion.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }

  @Test func testRoundtripSerialization() throws {
    let input = MessageWithRecursion(
      singular: MessageWithRecursion.Level0(
        level1: MessageWithRecursion.Level1(
          recurse: MessageWithRecursion(
            singular: MessageWithRecursion.Level0(
              side: MessageWithRecursion.NonRecursive(value: "roundtrip")
            )
          )
        )
      ),
      optional: MessageWithRecursion.Level0(
        side: MessageWithRecursion.NonRecursive(value: "optional-roundtrip")
      ),
      repeated: [
        MessageWithRecursion.Level0(
          side: MessageWithRecursion.NonRecursive(value: "repeated-roundtrip")
        )
      ],
      map: [
        "mapkey": MessageWithRecursion.Level0(
          side: MessageWithRecursion.NonRecursive(value: "map-roundtrip")
        )
      ]
    )

    let data = try JSONEncoder().encode(input)
    let decoded = try _ProtoJSONDecoder().decode(MessageWithRecursion.self, from: data)
    #expect(decoded == input)
  }
}
