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

/// Errors thrown by upload sources during read operations.
public enum UploadSourceError: Error, Sendable {
  /// An error occurred while reading from the upload source.
  case readError(underlyingError: any Error)
}

extension UploadSourceError {
  /// Creates an `UploadSourceError.readError` with the given underlying error.
  public static func readError(_ error: any Error) -> UploadSourceError {
    .readError(underlyingError: error)
  }
}

extension UploadSourceError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .readError(let underlyingError):
      return "readError(\(underlyingError))"
    }
  }
}
