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

/// Represents a month in the Gregorian calendar.
public enum Month: Int, Codable, Equatable {
  case unspecified = 0
  case january = 1
  case february = 2
  case march = 3
  case april = 4
  case may = 5
  case june = 6
  case july = 7
  case august = 8
  case september = 9
  case october = 10
  case november = 11
  case december = 12

  public init() {
    self = .unspecified
  }

  public var stringValue: String {
    switch self {
    case .unspecified: return "MONTH_UNSPECIFIED"
    case .january: return "JANUARY"
    case .february: return "FEBRUARY"
    case .march: return "MARCH"
    case .april: return "APRIL"
    case .may: return "MAY"
    case .june: return "JUNE"
    case .july: return "JULY"
    case .august: return "AUGUST"
    case .september: return "SEPTEMBER"
    case .october: return "OCTOBER"
    case .november: return "NOVEMBER"
    case .december: return "DECEMBER"
    }
  }

  public init?(stringValue: String) {
    switch stringValue {
    case "MONTH_UNSPECIFIED": self = .unspecified
    case "JANUARY": self = .january
    case "FEBRUARY": self = .february
    case "MARCH": self = .march
    case "APRIL": self = .april
    case "MAY": self = .may
    case "JUNE": self = .june
    case "JULY": self = .july
    case "AUGUST": self = .august
    case "SEPTEMBER": self = .september
    case "OCTOBER": self = .october
    case "NOVEMBER": self = .november
    case "DECEMBER": self = .december
    default: return nil
    }
  }
}
