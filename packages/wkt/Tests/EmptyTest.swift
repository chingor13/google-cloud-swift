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
import GoogleCloudWkt
import Testing

struct WrappedEmptyEncode: Encodable {
  let value: GoogleCloudWkt.Empty
}

@Test("Empty JSON Encoding")
func encodingJSON() throws {
  let wrapped = WrappedEmptyEncode(value: GoogleCloudWkt.Empty())
  let encoder = JSONEncoder()
  let data = try encoder.encode(wrapped)
  let jsonString = String(data: data, encoding: .utf8)
  #expect(jsonString == "{\"value\":{}}")
}

struct WrappedEmptyDecode: Decodable {
  let value: GoogleCloudWkt.Empty
}

@Test("Empty JSON Decoding")
func decodingJSON() throws {
  let jsonString = "{\"value\":{}}"
  let data = jsonString.data(using: .utf8)!
  let decoder = JSONDecoder()
  let wrapped = try decoder.decode(WrappedEmptyDecode.self, from: data)
  #expect(wrapped.value == Empty())
}
