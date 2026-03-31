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
  #expect(got.seconds() == args.0)
  #expect(got.nanos() == args.1)
}

@Test("Detect mismatched signs", arguments: [(123, -456), (-123, 456)])
func mismatchedSigns(_ args: (Int64, Int64)) throws {
  #expect(throws: GoogleCloudWkt.DurationError.mismatchedSigns) {
    try GoogleCloudWkt.Duration(seconds: args.0, nanos: args.1)
  }
}

let NS: Int64 = 1_000_000_000

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
  arguments: [NS, -NS])
func outOfRangeNanos(_ nanos: Int64) throws {
  #expect(throws: GoogleCloudWkt.DurationError.outOfRange) {
    try GoogleCloudWkt.Duration(seconds: 0, nanos: nanos)
  }
}
