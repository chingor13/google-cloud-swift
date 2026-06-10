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

@Suite struct DiscoveryBytes {
  typealias T = DiscoveryWithBytes

  @Test(
    arguments: [
      (#"{}"#, T()),
      (#"{"optional": null          }"#, T()),
      (#"{"optional": ""            }"#, T().with { $0.optional = Data() }),
      (#"{"optional": "NDI="        }"#, T().with { $0.optional = Data("42".utf8) }),
      (#"{"repeated": []            }"#, T()),
      (#"{"repeated": ["NDI="]      }"#, T().with { $0.repeated = [Data("42".utf8)] }),
      (#"{"repeated": ["NDI=", ""]  }"#, T().with { $0.repeated = [Data("42".utf8), Data()] }),
      (#"{"map":      {}            }"#, T()),
      (#"{"map":      {"a": "NDI="} }"#, T().with { $0.map = ["a": Data("42".utf8)] }),
    ])
  func deserialize(input: String, want: T) throws {
    let decoder = _ProtoJSONDecoder()
    let got = try decoder.decode(T.self, from: input.data(using: .utf8)!)
    #expect(got == want)
  }

  @Test(
    arguments: [
      (#"{"map":{},"optional":null,"repeated":[]}"#, T()),
      (#"{"map":{},"optional":"","repeated":[]}"#, T().with { $0.optional = Data() }),
      (#"{"map":{},"optional":"NDI=","repeated":[]}"#, T().with { $0.optional = Data("42".utf8) }),
      (
        #"{"map":{},"optional":null,"repeated":["NDI="]}"#,
        T().with { $0.repeated = [Data("42".utf8)] }
      ),
      (
        #"{"map":{},"optional":null,"repeated":["NDI=",""]}"#,
        T().with { $0.repeated = [Data("42".utf8), Data()] }
      ),
      (
        #"{"map":{"a":"NDI="},"optional":null,"repeated":[]}"#,
        T().with { $0.map = ["a": Data("42".utf8)] }
      ),
    ])
  func roundtrip(want: String, input: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(input)
    let got = String(data: data, encoding: .utf8)!
    #expect(want == got)

    let decoder = _ProtoJSONDecoder()
    let roundtrip = try decoder.decode(T.self, from: data)
    #expect(input == roundtrip)
  }
}
