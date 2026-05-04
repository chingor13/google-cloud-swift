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

/// Wrapper message for int64.
///
/// The JSON representation for Int64Value is JSON number.
public typealias Int64Value = Swift.Int64?

extension Swift.Int64: _SupportsOptionalPacking {
  public static var _optionalAnyTypeUrl: String {
    return "type.googleapis.com/google.protobuf.Int64Value"
  }

  public static func _unpackOptional(fromAny any: `Any`) throws -> Swift.Int64 {
    guard let v = any.fields[`Any`.valueField] else {
      throw AnyError.missingValueField
    }
    guard case let .number(n) = v else {
      throw AnyError.invalidValueField
    }
    return Int64(n)
  }

  public func _packOptional() throws -> Struct {
    return [`Any`.valueField: Value(number: Double(self))]
  }
}
