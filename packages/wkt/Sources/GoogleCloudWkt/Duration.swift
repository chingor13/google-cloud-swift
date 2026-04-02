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

/// A time duration type for Google APIs.
///
/// A Duration represents a signed, fixed-length span of time represented
/// as a count of seconds and fractions of seconds at nanosecond
/// resolution. It is independent of any calendar and concepts like "day"
/// or "month". It is related to ``Timestamp`` in that the
/// difference between two Timestamp values is a Duration and it can be added
/// or subtracted from a Timestamp. Range is approximately +-10,000 years.
///
/// # JSON Mapping
///
/// In JSON format, the Duration type is encoded as a string rather than an
/// object, where the string ends in the suffix "s" (indicating seconds) and
/// is preceded by the number of seconds, with nanoseconds expressed as
/// fractional seconds. For example, 3 seconds with 0 nanoseconds should be
/// encoded in JSON format as "3s", while 3 seconds and 1 nanosecond should
/// be expressed in JSON format as "3.000000001s", and 3 seconds and 1
/// microsecond should be expressed in JSON format as "3.000001s".
public struct Duration {
  public let seconds: Int64
  public let nanos: Int64

  /// Create a new instance, validating the inputs.
  ///
  /// - Parameters:
  ///   - seconds: the number of seconds in the span of time.
  ///   - nanos: the number of nanoseconds in the span of time. The sign must
  ///     match the sign in the seconds.
  ///
  /// - Throws: `DurationError.mismatchedSigns` if the seconds and nanoseconds
  ///     do not have matching signs.
  /// - Throws: `DurationError.outOfRange` if the seconds are outside the
  ///   [`minSeconds`, `maxSeconds`] range **or** the nanoseconds are
  ///   outside the [`minNanoseconds`, `maxNanoseconds`] range.
  public init(seconds: Int64, nanos: Int64) throws {
    if (seconds < 0 && nanos > 0) || (seconds > 0 && nanos < 0) {
      throw DurationError.mismatchedSigns
    }
    if seconds < minSeconds || seconds > maxSeconds {
      throw DurationError.outOfRange
    }
    if nanos < minNanos || nanos > maxNanos {
      throw DurationError.outOfRange
    }
    self.seconds = seconds
    self.nanos = nanos
  }
}

extension Duration: Encodable {
  public func encode(to encoder: any Encoder) throws {
    if nanos == 0 {
      try String("\(seconds)s").encode(to: encoder)
      return
    }
    if seconds < 0 || (seconds == 0 && nanos < 0) {
      let secondsStr = String(format: "%lld", abs(seconds))
      let nanosStr = formatNanos(nanos: abs(nanos))
      try String("-\(secondsStr).\(nanosStr)s").encode(to: encoder)
      return
    }
    let secondsStr = String(format: "%lld", seconds)
    let nanosStr = formatNanos(nanos: nanos)
    try String("\(secondsStr).\(nanosStr)s").encode(to: encoder)
  }
}

extension Duration: Decodable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let string = try container.decode(String.self)

    guard string.hasSuffix("s") else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Duration string must end with 's'")
    }
    let withoutSuffix = string.dropLast()

    let isNegative = withoutSuffix.hasPrefix("-")
    let unsignedStr = isNegative ? withoutSuffix.dropFirst() : withoutSuffix

    if unsignedStr.isEmpty {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Duration string is empty")
    }

    let parts = unsignedStr.split(separator: ".", omittingEmptySubsequences: false)
    guard parts.count <= 2 else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Duration string has multiple decimals")
    }

    let secondsStr = parts[0].isEmpty ? "0" : String(parts[0])
    guard let seconds = Int64(secondsStr) else {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Invalid seconds component")
    }

    var nanos: Int64 = 0
    if parts.count == 2 {
      let nanosStr = String(parts[1]).padding(toLength: 9, withPad: "0", startingAt: 0)
      guard let pNanos = Int64(nanosStr) else {
        throw DecodingError.dataCorruptedError(
          in: container, debugDescription: "Invalid nanoseconds component")
      }
      nanos = pNanos
    }

    do {
      try self.init(seconds: isNegative ? -seconds : seconds, nanos: isNegative ? -nanos : nanos)
    } catch {
      throw DecodingError.dataCorruptedError(
        in: container, debugDescription: "Parsed values out of range or mismatched: \(error)")
    }
  }
}

func formatNanos(nanos: Int64) -> String {
  var result = String(format: "%09d", nanos)
  // ProtoJSON requires either millisecond, microsecond, or nanosecond precision.
  if result.hasSuffix("000") {
    result.removeLast(3)
  }
  if result.hasSuffix("000") {
    result.removeLast(3)
  }
  return result
}

/// An error type for the `Duration` initializer.
public enum DurationError: Error {
  /// The seconds and nanosecond signs did no match.
  case mismatchedSigns
  /// The seconds or nanosecond components are out of range.
  case outOfRange
}

/// The number of nanoseconds in a second.
let nanosPerSecond: Int64 = 1_000_000_000

/// The maximum value for the `seconds` component, approximately 10,000 years.
public let maxSeconds: Int64 = 315_576_000_000

/// The minimum value for the `seconds` component, approximately -10,000 years.
public let minSeconds: Int64 = -maxSeconds

/// The maximum value for the `nanos` component.
public let maxNanos: Int64 = nanosPerSecond - 1

/// The minimum value for the `nanos` component.
public let minNanos: Int64 = -maxNanos
