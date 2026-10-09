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

/// A builder and container for Google Cloud `x-goog-api-client` telemetry headers.
///
/// Google Cloud APIs use the `x-goog-api-client` header to collect client library
/// usage and adoption metrics. The header consists of a space-separated list of
/// `NAME "/" VERSION` tokens (e.g., `gl-swift/apple-6.3-lang-6.3 gax/0.5.0 rest/0.5.0 gapic/0.5.0`).
///
/// Standard token names include:
/// - `gl-swift`: Language runtime and compiler version.
/// - `gax`: Google API Extensions (GAX) version.
/// - `rest`: REST/HTTP transport version.
/// - `grpc`: gRPC transport version.
/// - `gapic`: Generated GAPIC client library version.
/// - `gccl`: Google Cloud Client Library (veneer) version.
/// - `pb`: Swift Protobuf runtime version.
///
/// See [System Parameters](https://docs.cloud.google.com/apis/docs/system-parameters)
/// and [go/cloud-api-headers](https://docs.google.com/document/d/1Afm2EGsYRlrk4-YBoEOHIIB-0X-CSkfqUT5xEXNozls).
struct _ApiClientHeader: Sendable, Equatable, CustomStringConvertible {
  enum Token: Hashable, Sendable {
    case swiftLanguage
    case gccl
    case gapic
    case gax
    case grpc
    case rest
    case custom(String)

    var name: String {
      switch self {
      case .swiftLanguage: return "gl-swift"
      case .gccl: return "gccl"
      case .gapic: return "gapic"
      case .gax: return "gax"
      case .grpc: return "grpc"
      case .rest: return "rest"
      case .custom(let name): return name
      }
    }

    fileprivate var sortRank: Int {
      switch self {
      case .swiftLanguage: return 0
      case .gccl: return 1
      case .gapic: return 2
      case .gax: return 3
      case .grpc: return 4
      case .rest: return 5
      case .custom: return 10
      }
    }
  }

  private var tokens: [Token: String]

  /// The standard HTTP header name (`x-goog-api-client`).
  static let headerName = _HeaderNames.apiClient

  /// Creates a header populated with default environment tokens (`gl-swift` and `gax`).
  init() {
    self.tokens = [
      .swiftLanguage: defaultLanguageTokenVersion(),
      .gax: gaxVersion(),
    ]
  }

  /// Sets or updates a token.
  mutating func setToken(_ token: Token, version: String) {
    switch token {
    case .custom(let name):
      switch name {
      case "gl-swift": self.tokens[.swiftLanguage] = version
      case "gccl": self.tokens[.gccl] = version
      case "gapic": self.tokens[.gapic] = version
      case "gax": self.tokens[.gax] = version
      case "grpc": self.tokens[.grpc] = version
      case "rest": self.tokens[.rest] = version
      default: self.tokens[token] = version
      }
    default:
      self.tokens[token] = version
    }
  }

  /// Formats the header into its canonical space-separated string representation.
  func build() -> String {
    self.tokens
      .sorted { lhs, rhs in
        if lhs.key.sortRank != rhs.key.sortRank {
          return lhs.key.sortRank < rhs.key.sortRank
        }
        return lhs.key.name < rhs.key.name
      }
      .map { "\($0.key.name)/\($0.value)" }
      .joined(separator: " ")
  }

  var description: String { self.build() }
}

func defaultLanguageTokenVersion() -> String {
  "apple-\(compilerVersion())-lang-\(swiftCompatVersion())"
}

@_spi(GoogleCloudInternal)
public func _gapicApiClientHeader(packageVersion: String) -> String {
  var header = _ApiClientHeader()
  header.setToken(.rest, version: gaxVersion())
  header.setToken(.gapic, version: packageVersion)
  return header.build()
}

@_spi(GoogleCloudInternal)
public func _veneerApiClientHeader(packageVersion: String) -> String {
  // gccl == Google Cloud Client Library
  var header = _ApiClientHeader()
  header.setToken(.rest, version: gaxVersion())
  header.setToken(.gccl, version: packageVersion)
  return header.build()
}

func compilerVersion() -> String {
  // Apparently Swift does not have a macro or function to detect the compiler version.
  #if compiler(>=8.0)
    return "8.0"
  #elseif compiler(>=7.4)
    return "7.4"
  #elseif compiler(>=7.3)
    return "7.3"
  #elseif compiler(>=7.2)
    return "7.2"
  #elseif compiler(>=7.1)
    return "7.1"
  #elseif compiler(>=7.0)
    return "7.0"
  #elseif compiler(>=6.6)
    return "6.6"
  #elseif compiler(>=6.5)
    return "6.5"
  #elseif compiler(>=6.4)
    return "6.4"
  #elseif compiler(>=6.3)
    return "6.3"
  #elseif compiler(>=6.2)
    return "6.2"
  #else
    // Stop compilation. Should not be that hard to keep this function up to date, we will need to
    // update our code to compile with each major release anyway.
    #error("This version of the Swift compiler is unknown or unsupported")
  #endif
}

func swiftCompatVersion() -> String {
  // Apparently Swift does not have a macro or function to detect the language version.
  #if swift(>=8.0)
    return "8.0"
  #elseif swift(>=7.4)
    return "7.4"
  #elseif swift(>=7.3)
    return "7.3"
  #elseif swift(>=7.2)
    return "7.2"
  #elseif swift(>=7.1)
    return "7.1"
  #elseif swift(>=7.0)
    return "7.0"
  #elseif swift(>=6.6)
    return "6.6"
  #elseif swift(>=6.5)
    return "6.5"
  #elseif swift(>=6.4)
    return "6.4"
  #elseif swift(>=6.3)
    return "6.3"
  #elseif swift(>=6.2)
    return "6.2"
  #else
    // Stop compilation. Should not be that hard to keep this function up to date, we will need to
    // update our code to compile with each major release anyway.
    #error("This version of Swift is unknown or unsupported")
  #endif
}

func gaxVersion() -> String {
  return PackageVersion.version
}
