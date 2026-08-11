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

import Crypto
import Foundation
@_spi(GoogleCloudInternal) import struct GoogleCloudGax._CRC32C

struct DownloadChecksummer: Sendable {
  let options: ChecksumOptions
  let metadata: ReadObjectMetadata
  let isPartialContent: Bool
  let isDecompressivelyTranscoded: Bool

  private var crc32c = _CRC32C()
  private var md5 = Insecure.MD5()

  init(
    options: ChecksumOptions,
    metadata: ReadObjectMetadata,
    isPartialContent: Bool = false,
    isDecompressivelyTranscoded: Bool = false
  ) {
    self.options = options
    self.metadata = metadata
    self.isPartialContent = isPartialContent
    self.isDecompressivelyTranscoded = isDecompressivelyTranscoded
  }

  mutating func update(_ data: Data) {
    if options.crc32c != nil {
      crc32c.update(data)
    }
    if options.md5 != nil {
      md5.update(data: data)
    }
  }

  func validate() throws {
    // Validate CRC32C
    if let crcOption = options.crc32c {
      switch crcOption {
      case .auto:
        if !isPartialContent && !isDecompressivelyTranscoded, let expected = metadata.crc32c {
          let bigEndian = crc32c.finalize().bigEndian
          let actual = withUnsafeBytes(of: bigEndian) { Data($0).base64EncodedString() }
          let normalizedExpected = Self.normalize(expected, prefix: "crc32c=")
          if actual != normalizedExpected {
            throw DownloadError.checksumMismatch(
              expected: normalizedExpected, actual: actual, algorithm: "crc32c")
          }
        }
      case .value(let expected):
        let bigEndian = crc32c.finalize().bigEndian
        let actual = withUnsafeBytes(of: bigEndian) { Data($0).base64EncodedString() }
        let normalizedExpected = Self.normalize(expected, prefix: "crc32c=")
        if actual != normalizedExpected {
          throw DownloadError.checksumMismatch(
            expected: normalizedExpected, actual: actual, algorithm: "crc32c")
        }
      }
    }

    // Validate MD5
    if let md5Option = options.md5 {
      switch md5Option {
      case .auto:
        if !isPartialContent && !isDecompressivelyTranscoded, let expected = metadata.md5Hash {
          let digest = md5.finalize()
          let actual = Data(digest).base64EncodedString()
          let normalizedExpected = Self.normalize(expected, prefix: "md5=")
          if actual != normalizedExpected {
            throw DownloadError.checksumMismatch(
              expected: normalizedExpected, actual: actual, algorithm: "md5")
          }
        }
      case .value(let expected):
        let digest = md5.finalize()
        let actual = Data(digest).base64EncodedString()
        let normalizedExpected = Self.normalize(expected, prefix: "md5=")
        if actual != normalizedExpected {
          throw DownloadError.checksumMismatch(
            expected: normalizedExpected, actual: actual, algorithm: "md5")
        }
      }
    }
  }

  private static func normalize(_ value: String, prefix: String) -> String {
    if value.hasPrefix(prefix) {
      return String(value.dropFirst(prefix.count))
    }
    return value
  }
}
