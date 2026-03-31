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
  private let seconds_: Int64
  private let nanos_: Int64

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
    self.seconds_ = seconds
    self.nanos_ = nanos
  }

  /// The number of seconds in this span of time.
  public func seconds() -> Int64 {
    return self.seconds_
  }

  /// The fractional number of nanoseconds in this span of time.
  public func nanos() -> Int64 {
    return self.nanos_
  }
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
