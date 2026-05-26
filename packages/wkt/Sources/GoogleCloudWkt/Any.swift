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

/// `Any` contains an arbitrary message along with a URL that describes the type
/// of the message.
///
/// The message is kept in serialized form, as they are typically received from
/// the wire and their type may not be known in the receiving application.
///
/// Only known types may be extracted from an `Any`.
public struct `Any`: Codable, Equatable, Sendable {
  let _type: String
  let fields: Struct

  /// Return the type URL of the contents, or `nil` if it is unknown.
  ///
  /// Values without a typeURL indicate a decoding error. The contents
  /// cannot be extracted.
  public var typeUrl: String {
    get {
      return self._type
    }
  }

  enum CodingKeys: String, CodingKey {
    case type = "@type"  // must be literal, cannot use `typeUrlField`
  }

  public init(from decoder: Decoder) throws {
    var fields = try Struct(from: decoder)
    guard case let .string(ty)? = fields.removeValue(forKey: Self.typeUrlField) else {
      throw DecodingError.keyNotFound(
        CodingKeys.type,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "\(Self.typeUrlField) is required for Any"))
    }
    self._type = ty
    self.fields = fields
  }

  public func encode(to encoder: any Encoder) throws {
    // This should be efficient, as the dictionary is a copy-on-write data structure.
    var fields = self.fields
    fields[Self.typeUrlField] = Value(string: self._type)
    try fields.encode(to: encoder)
  }

  public init<M: _AnyPackable>(fromMessage message: M) throws {
    self._type = M._anyTypeUrl
    self.fields = try message._pack()
  }
}

// Makes `Any` conform to the `_AnyPackable` protocol, so we can pack and unpack them from `Any`.
extension `Any`: _AnyPackable {
  public static var _anyTypeUrl: String {
    return "type.googleapis.com/google.protobuf.Any"
  }
  public init(fromAny any: `Any`) throws {
    guard case var .object(fields)? = any.fields["value"] else {
      throw AnyError.invalidValueField
    }
    guard case let .string(_type)? = fields.removeValue(forKey: Self.typeUrlField) else {
      throw AnyError.invalidNestedAnyType
    }
    self._type = _type
    self.fields = fields
  }
  public func _pack() throws -> Struct {
    var fields = self.fields
    fields[Self.typeUrlField] = Value(string: self._type)
    return [Self.valueField: Value(object: fields)]
  }

  // The JSON field used to store an Any's typeUrl.
  static private let typeUrlField = "@type"
  // The JSON field used to store types with custom encoding.
  static internal let valueField = "value"
}

/// A type conforming to the `_AnyPackable` protocol can be packed into and unpacked from ``Any``.
public protocol _AnyPackable {
  static var _anyTypeUrl: String { get }
  init(fromAny any: `Any`) throws
  func _pack() throws -> Struct
}

// Deserializes a message of type `M` from an `Any`.
public func _slowAnyDeserialize<M: Decodable>(_ type: M.Type, from: `Any`) throws -> M {
  let encoder = JSONEncoder();
  encoder.outputFormatting = [.withoutEscapingSlashes]
  let data = try encoder.encode(from.fields)
  let decoder = _ProtoJSONDecoder()
  return try decoder.decode(M.self, from: data)
}

// Serializes a message of type `M` into an `Any`.
public func _slowAnySerialize<M: Encodable>(message: M) throws -> Struct {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.withoutEscapingSlashes]
  let data = try encoder.encode(message)
  let decoder = _ProtoJSONDecoder()
  return try decoder.decode(Struct.self, from: data)
}
