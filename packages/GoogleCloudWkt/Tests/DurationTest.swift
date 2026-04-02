// swift-tools-version: 6.2
//
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

@Test(
  "Initializer",
  arguments: [(123, 456), (-123, -456), (123, 0), (-123, 0), (0, 456), (0, -456)])
func initNormal(_ args: (Int64, Int64)) throws {
  let got = try GoogleCloudWkt.Duration(seconds: args.0, nanos: args.1)
  #expect(got.seconds == args.0)
  #expect(got.nanos == args.1)
}

@Test("Detect mismatched signs", arguments: [(123, -456), (-123, 456)])
func mismatchedSigns(_ args: (Int64, Int64)) throws {
  #expect(throws: GoogleCloudWkt.DurationError.mismatchedSigns) {
    try GoogleCloudWkt.Duration(seconds: args.0, nanos: args.1)
  }
}

let nanosPerSecond: Int64 = 1_000_000_000

@Test(
  "Detect out of range seconds",
  arguments: [GoogleCloudWkt.maxSeconds + 1, GoogleCloudWkt.minSeconds - 1])
func outOfRangeSeconds(_ seconds: Int64) throws {
  #expect(throws: GoogleCloudWkt.DurationError.outOfRange) {
    try GoogleCloudWkt.Duration(seconds: seconds, nanos: 0)
  }
}

@Test(
  "Detect out of range nanos",
  arguments: [nanosPerSecond, -nanosPerSecond])
func outOfRangeNanos(_ nanos: Int64) throws {
  #expect(throws: GoogleCloudWkt.DurationError.outOfRange) {
    try GoogleCloudWkt.Duration(seconds: 0, nanos: nanos)
  }
}

struct WrappedDuration: Encodable {
  let value: GoogleCloudWkt.Duration
}

@Test(
  "Encoding JSON",
  arguments: [
    (1, 0, "{\"value\":\"1s\"}"),
    (1, 1000, "{\"value\":\"1.000001s\"}"),
    (1, 1_000_000, "{\"value\":\"1.001s\"}"),
    (1, 70_000_000, "{\"value\":\"1.070s\"}"),
    (1, 70_000, "{\"value\":\"1.000070s\"}"),
    (1, 70, "{\"value\":\"1.000000070s\"}"),
    (0, 1, "{\"value\":\"0.000000001s\"}"),
    (-1, 0, "{\"value\":\"-1s\"}"),
    (-1, -1_000_000, "{\"value\":\"-1.001s\"}"),
    (-1, -70_000_000, "{\"value\":\"-1.070s\"}"),
    (-1, -70_000, "{\"value\":\"-1.000070s\"}"),
    (-1, -70, "{\"value\":\"-1.000000070s\"}"),
    (0, -1_000_000, "{\"value\":\"-0.001s\"}"),
    (42, 0, "{\"value\":\"42s\"}"),
    (-42, 0, "{\"value\":\"-42s\"}"),
    (42, 1_000_000, "{\"value\":\"42.001s\"}"),
    (-42, -1_000_000, "{\"value\":\"-42.001s\"}"),
    (315_576_000_000, 0, "{\"value\":\"315576000000s\"}"),
    (-315_576_000_000, 0, "{\"value\":\"-315576000000s\"}"),
    (315_576_000_000, 999_999_999, "{\"value\":\"315576000000.999999999s\"}"),
    (-315_576_000_000, -999_999_999, "{\"value\":\"-315576000000.999999999s\"}"),
  ])
func encodeJSON(_ args: (Int64, Int64, String)) throws {
  let duration = try GoogleCloudWkt.Duration(seconds: args.0, nanos: args.1)
  let wrapped = WrappedDuration(value: duration)
  let encoder = JSONEncoder()
  let data = try encoder.encode(wrapped)
  let got = String(data: data, encoding: .utf8)!
  #expect(got == args.2)
}

struct WrappedDurationDecode: Decodable {
  let value: GoogleCloudWkt.Duration
}

@Test(
  "Decoding JSON",
  arguments: [
    ("{\"value\":\"1s\"}", 1, 0),
    ("{\"value\":\"1.001s\"}", 1, 1_000_000),
    ("{\"value\":\"1.070s\"}", 1, 70_000_000),
    ("{\"value\":\"1.07s\"}", 1, 70_000_000),
    ("{\"value\":\"1.1s\"}", 1, 100_000_000),
    ("{\"value\":\"1.12s\"}", 1, 120_000_000),
    ("{\"value\":\"1.1234s\"}", 1, 123_400_000),
    ("{\"value\":\"1.12345s\"}", 1, 123_450_000),
    ("{\"value\":\"1.1234567s\"}", 1, 123_456_700),
    ("{\"value\":\"1.12345678s\"}", 1, 123_456_780),
    ("{\"value\":\"0.000000001s\"}", 0, 1),
    ("{\"value\":\"-1s\"}", -1, 0),
    ("{\"value\":\"-1.070s\"}", -1, -70_000_000),
    ("{\"value\":\"-1.001s\"}", -1, -1_000_000),
    ("{\"value\":\"-0.001s\"}", 0, -1_000_000),
    ("{\"value\":\"42s\"}", 42, 0),
    ("{\"value\":\"-42s\"}", -42, 0),
    ("{\"value\":\"42.001s\"}", 42, 1_000_000),
    ("{\"value\":\"-42.001s\"}", -42, -1_000_000),
    ("{\"value\":\"315576000000s\"}", 315_576_000_000, 0),
    ("{\"value\":\"-315576000000s\"}", -315_576_000_000, 0),
    ("{\"value\":\"315576000000.999999999s\"}", 315_576_000_000, 999_999_999),
    ("{\"value\":\"-315576000000.999999999s\"}", -315_576_000_000, -999_999_999),
  ])
func decodeJSON(_ args: (String, Int64, Int64)) throws {
  let data = args.0.data(using: .utf8)!
  let decoder = JSONDecoder()
  let wrapped = try decoder.decode(WrappedDurationDecode.self, from: data)
  #expect(wrapped.value.seconds == args.1)
  #expect(wrapped.value.nanos == args.2)
}
