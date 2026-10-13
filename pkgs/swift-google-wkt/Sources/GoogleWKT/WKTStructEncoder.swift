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

/// Encodes `Encodable` messages directly into a `WKTStruct` (`[String: WKTValue]`) in memory,
/// applying ProtoJSON rules without intermediate UTF-8 JSON serialization.
struct WKTStructEncoder {
  var omitEmptyCollections: Bool = true

  init(omitEmptyCollections: Bool = true) {
    self.omitEmptyCollections = omitEmptyCollections
  }

  func encode<T: Encodable>(_ value: T) throws -> WKTStruct {
    let wktValue = try Self.encodeToValue(
      value, codingPath: [], omitEmptyCollections: self.omitEmptyCollections)
    guard case .object(let dict) = wktValue else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: [],
          debugDescription: "Expected \(T.self) to encode into a JSON object (WKTStruct)."
        )
      )
    }
    return dict
  }

  static func encodeToValue<T: Encodable>(
    _ value: T,
    codingPath: [any CodingKey],
    omitEmptyCollections: Bool
  ) throws -> WKTValue {
    if let opt = value as? any _OptionalProtocol {
      guard let unwrapped = opt._unwrappedValue else {
        return .null(WKTNullValue())
      }
      if let v = unwrapped as? Int64 {
        return .string(String(v))
      } else if let v = unwrapped as? UInt64 {
        return .string(String(v))
      } else if let v = unwrapped as? Int128 {
        return .string(String(v))
      } else if let v = unwrapped as? UInt128 {
        return .string(String(v))
      }
    }

    if let v = value as? WKTValue {
      try validateWKTValue(v, codingPath: codingPath)
      return v
    } else if let v = value as? WKTStruct {
      for (k, entry) in v {
        try validateWKTValue(entry, codingPath: codingPath + [_DynamicCodingKey(stringValue: k)])
      }
      return .object(v)
    } else if let v = value as? WKTListValue {
      for (idx, entry) in v.enumerated() {
        try validateWKTValue(entry, codingPath: codingPath + [_DynamicCodingKey(intValue: idx)!])
      }
      return .array(v)
    } else if let v = value as? Int64 {
      return .string(String(v))
    } else if let v = value as? UInt64 {
      return .string(String(v))
    } else if let v = value as? Int128 {
      return .string(String(v))
    } else if let v = value as? UInt128 {
      return .string(String(v))
    } else if let v = value as? String {
      return .string(v)
    } else if let v = value as? Bool {
      return .bool(v)
    } else if let v = value as? Double {
      return encodeDouble(v)
    } else if let v = value as? Float {
      return encodeFloat(v)
    } else if let v = value as? Int {
      return .number(Double(v))
    } else if let v = value as? Int8 {
      return .number(Double(v))
    } else if let v = value as? Int16 {
      return .number(Double(v))
    } else if let v = value as? Int32 {
      return .number(Double(v))
    } else if let v = value as? UInt {
      return .number(Double(v))
    } else if let v = value as? UInt8 {
      return .number(Double(v))
    } else if let v = value as? UInt16 {
      return .number(Double(v))
    } else if let v = value as? UInt32 {
      return .number(Double(v))
    } else if let v = value as? Data {
      return .string(v.base64EncodedString())
    }

    let node = EncodingNode()
    let encoder = InternalStructEncoder(
      node: node, codingPath: codingPath, omitEmptyCollections: omitEmptyCollections)
    try value.encode(to: encoder)
    return node.toWKTValue()
  }

  static func encodeDouble(_ value: Double) -> WKTValue {
    if value.isNaN {
      return .string("NaN")
    } else if value == .infinity {
      return .string("Infinity")
    } else if value == -.infinity {
      return .string("-Infinity")
    } else {
      return .number(value)
    }
  }

  static func encodeFloat(_ value: Float) -> WKTValue {
    if value.isNaN {
      return .string("NaN")
    } else if value == .infinity {
      return .string("Infinity")
    } else if value == -.infinity {
      return .string("-Infinity")
    } else {
      let rounded = Double(String(value)) ?? Double(value)
      return .number(rounded)
    }
  }

  private static func validateWKTValue(_ value: WKTValue, codingPath: [any CodingKey]) throws {
    switch value {
    case .number(let v):
      guard v.isFinite else {
        throw EncodingError.invalidValue(
          v,
          EncodingError.Context(
            codingPath: codingPath,
            debugDescription: "Value.number cannot be NaN or Infinity."
          )
        )
      }
    case .object(let dict):
      for (k, entry) in dict {
        try validateWKTValue(entry, codingPath: codingPath + [_DynamicCodingKey(stringValue: k)])
      }
    case .array(let list):
      for (idx, entry) in list.enumerated() {
        try validateWKTValue(entry, codingPath: codingPath + [_DynamicCodingKey(intValue: idx)!])
      }
    case .null, .string, .bool:
      break
    }
  }
}

fileprivate final class EncodingNode {
  enum Entry {
    case value(WKTValue)
    case node(EncodingNode)

    func toWKTValue() -> WKTValue {
      switch self {
      case .value(let v):
        return v
      case .node(let n):
        return n.toWKTValue()
      }
    }
  }

  enum Storage {
    case empty
    case singleValue(WKTValue)
    case object([String: Entry])
    case array([Entry])
  }

  var storage: Storage = .empty

  init(storage: Storage = .empty) {
    self.storage = storage
  }

  func setObjectEntry(_ entry: Entry, forKey key: String) {
    switch self.storage {
    case .object(var dict):
      dict[key] = entry
      self.storage = .object(dict)
    default:
      self.storage = .object([key: entry])
    }
  }

  func ensureObject() {
    if case .empty = self.storage {
      self.storage = .object([:])
    }
  }

  func appendArrayEntry(_ entry: Entry) {
    switch self.storage {
    case .array(var list):
      list.append(entry)
      self.storage = .array(list)
    default:
      self.storage = .array([entry])
    }
  }

  func ensureArray() {
    if case .empty = self.storage {
      self.storage = .array([])
    }
  }

  var arrayCount: Int {
    if case .array(let list) = self.storage {
      return list.count
    }
    return 0
  }

  func toWKTValue() -> WKTValue {
    switch self.storage {
    case .empty:
      return .object([:])
    case .singleValue(let v):
      return v
    case .object(let dict):
      return .object(dict.mapValues { $0.toWKTValue() })
    case .array(let list):
      return .array(list.map { $0.toWKTValue() })
    }
  }
}

fileprivate struct InternalStructEncoder: Encoder {
  let node: EncodingNode
  let codingPath: [any CodingKey]
  let omitEmptyCollections: Bool

  var userInfo: [CodingUserInfoKey: Any] { [:] }

  func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
    self.node.ensureObject()
    return KeyedEncodingContainer(
      InternalKeyedStructEncodingContainer<Key>(
        node: self.node,
        codingPath: self.codingPath,
        omitEmptyCollections: self.omitEmptyCollections
      )
    )
  }

  func unkeyedContainer() -> any UnkeyedEncodingContainer {
    self.node.ensureArray()
    return InternalUnkeyedStructEncodingContainer(
      node: self.node,
      codingPath: self.codingPath,
      omitEmptyCollections: self.omitEmptyCollections
    )
  }

  func singleValueContainer() -> any SingleValueEncodingContainer {
    return InternalSingleValueStructEncodingContainer(
      node: self.node,
      codingPath: self.codingPath,
      omitEmptyCollections: self.omitEmptyCollections
    )
  }
}

fileprivate struct InternalKeyedStructEncodingContainer<K: CodingKey>:
  KeyedEncodingContainerProtocol
{
  typealias Key = K

  let node: EncodingNode
  let codingPath: [any CodingKey]
  let omitEmptyCollections: Bool

  mutating func encodeNil(forKey key: K) throws {
    self.node.setObjectEntry(.value(.null(WKTNullValue())), forKey: key.stringValue)
  }

  mutating func encode(_ value: Bool, forKey key: K) throws {
    self.node.setObjectEntry(.value(.bool(value)), forKey: key.stringValue)
  }

  mutating func encode(_ value: String, forKey key: K) throws {
    self.node.setObjectEntry(.value(.string(value)), forKey: key.stringValue)
  }

  mutating func encode(_ value: Double, forKey key: K) throws {
    self.node.setObjectEntry(
      .value(WKTStructEncoder.encodeDouble(value)), forKey: key.stringValue)
  }

  mutating func encode(_ value: Float, forKey key: K) throws {
    self.node.setObjectEntry(
      .value(WKTStructEncoder.encodeFloat(value)), forKey: key.stringValue)
  }

  mutating func encode(_ value: Int, forKey key: K) throws {
    self.node.setObjectEntry(.value(.number(Double(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: Int8, forKey key: K) throws {
    self.node.setObjectEntry(.value(.number(Double(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: Int16, forKey key: K) throws {
    self.node.setObjectEntry(.value(.number(Double(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: Int32, forKey key: K) throws {
    self.node.setObjectEntry(.value(.number(Double(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: Int64, forKey key: K) throws {
    self.node.setObjectEntry(.value(.string(String(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: Int128, forKey key: K) throws {
    self.node.setObjectEntry(.value(.string(String(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: UInt, forKey key: K) throws {
    self.node.setObjectEntry(.value(.number(Double(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: UInt8, forKey key: K) throws {
    self.node.setObjectEntry(.value(.number(Double(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: UInt16, forKey key: K) throws {
    self.node.setObjectEntry(.value(.number(Double(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: UInt32, forKey key: K) throws {
    self.node.setObjectEntry(.value(.number(Double(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: UInt64, forKey key: K) throws {
    self.node.setObjectEntry(.value(.string(String(value))), forKey: key.stringValue)
  }

  mutating func encode(_ value: UInt128, forKey key: K) throws {
    self.node.setObjectEntry(.value(.string(String(value))), forKey: key.stringValue)
  }

  mutating func encodeIfPresent<T>(_ value: T?, forKey key: K) throws where T: Encodable {
    guard let value = value else { return }
    let encoded = try WKTStructEncoder.encodeToValue(
      value,
      codingPath: self.codingPath + [key],
      omitEmptyCollections: self.omitEmptyCollections
    )
    self.node.setObjectEntry(.value(encoded), forKey: key.stringValue)
  }

  mutating func encode<T>(_ value: T, forKey key: K) throws where T: Encodable {
    if self.omitEmptyCollections {
      if let checkable = value as? any _EmptyCollectionProtocol, checkable._isEmptyCollection {
        return
      }
    }
    let encoded = try WKTStructEncoder.encodeToValue(
      value,
      codingPath: self.codingPath + [key],
      omitEmptyCollections: self.omitEmptyCollections
    )
    self.node.setObjectEntry(.value(encoded), forKey: key.stringValue)
  }

  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: K)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
  {
    let childNode = EncodingNode(storage: .object([:]))
    self.node.setObjectEntry(.node(childNode), forKey: key.stringValue)
    return KeyedEncodingContainer(
      InternalKeyedStructEncodingContainer<NestedKey>(
        node: childNode,
        codingPath: self.codingPath + [key],
        omitEmptyCollections: self.omitEmptyCollections
      )
    )
  }

  mutating func nestedUnkeyedContainer(forKey key: K) -> any UnkeyedEncodingContainer {
    let childNode = EncodingNode(storage: .array([]))
    self.node.setObjectEntry(.node(childNode), forKey: key.stringValue)
    return InternalUnkeyedStructEncodingContainer(
      node: childNode,
      codingPath: self.codingPath + [key],
      omitEmptyCollections: self.omitEmptyCollections
    )
  }

  mutating func superEncoder() -> any Encoder {
    let superKey = _DynamicCodingKey(stringValue: "super")
    let childNode = EncodingNode()
    self.node.setObjectEntry(.node(childNode), forKey: superKey.stringValue)
    return InternalStructEncoder(
      node: childNode,
      codingPath: self.codingPath + [superKey],
      omitEmptyCollections: self.omitEmptyCollections
    )
  }

  mutating func superEncoder(forKey key: K) -> any Encoder {
    let childNode = EncodingNode()
    self.node.setObjectEntry(.node(childNode), forKey: key.stringValue)
    return InternalStructEncoder(
      node: childNode,
      codingPath: self.codingPath + [key],
      omitEmptyCollections: self.omitEmptyCollections
    )
  }
}

fileprivate struct InternalUnkeyedStructEncodingContainer: UnkeyedEncodingContainer {
  let node: EncodingNode
  let codingPath: [any CodingKey]
  let omitEmptyCollections: Bool

  var count: Int { self.node.arrayCount }

  mutating func encodeNil() throws {
    self.node.appendArrayEntry(.value(.null(WKTNullValue())))
  }

  mutating func encode(_ value: Bool) throws {
    self.node.appendArrayEntry(.value(.bool(value)))
  }

  mutating func encode(_ value: String) throws {
    self.node.appendArrayEntry(.value(.string(value)))
  }

  mutating func encode(_ value: Double) throws {
    self.node.appendArrayEntry(.value(WKTStructEncoder.encodeDouble(value)))
  }

  mutating func encode(_ value: Float) throws {
    self.node.appendArrayEntry(.value(WKTStructEncoder.encodeFloat(value)))
  }

  mutating func encode(_ value: Int) throws {
    self.node.appendArrayEntry(.value(.number(Double(value))))
  }

  mutating func encode(_ value: Int8) throws {
    self.node.appendArrayEntry(.value(.number(Double(value))))
  }

  mutating func encode(_ value: Int16) throws {
    self.node.appendArrayEntry(.value(.number(Double(value))))
  }

  mutating func encode(_ value: Int32) throws {
    self.node.appendArrayEntry(.value(.number(Double(value))))
  }

  mutating func encode(_ value: Int64) throws {
    self.node.appendArrayEntry(.value(.string(String(value))))
  }

  mutating func encode(_ value: Int128) throws {
    self.node.appendArrayEntry(.value(.string(String(value))))
  }

  mutating func encode(_ value: UInt) throws {
    self.node.appendArrayEntry(.value(.number(Double(value))))
  }

  mutating func encode(_ value: UInt8) throws {
    self.node.appendArrayEntry(.value(.number(Double(value))))
  }

  mutating func encode(_ value: UInt16) throws {
    self.node.appendArrayEntry(.value(.number(Double(value))))
  }

  mutating func encode(_ value: UInt32) throws {
    self.node.appendArrayEntry(.value(.number(Double(value))))
  }

  mutating func encode(_ value: UInt64) throws {
    self.node.appendArrayEntry(.value(.string(String(value))))
  }

  mutating func encode(_ value: UInt128) throws {
    self.node.appendArrayEntry(.value(.string(String(value))))
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    let idxKey = _DynamicCodingKey(intValue: self.count)!
    let encoded = try WKTStructEncoder.encodeToValue(
      value,
      codingPath: self.codingPath + [idxKey],
      omitEmptyCollections: self.omitEmptyCollections
    )
    self.node.appendArrayEntry(.value(encoded))
  }

  mutating func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type)
    -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
  {
    let idxKey = _DynamicCodingKey(intValue: self.count)!
    let childNode = EncodingNode(storage: .object([:]))
    self.node.appendArrayEntry(.node(childNode))
    return KeyedEncodingContainer(
      InternalKeyedStructEncodingContainer<NestedKey>(
        node: childNode,
        codingPath: self.codingPath + [idxKey],
        omitEmptyCollections: self.omitEmptyCollections
      )
    )
  }

  mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer {
    let idxKey = _DynamicCodingKey(intValue: self.count)!
    let childNode = EncodingNode(storage: .array([]))
    self.node.appendArrayEntry(.node(childNode))
    return InternalUnkeyedStructEncodingContainer(
      node: childNode,
      codingPath: self.codingPath + [idxKey],
      omitEmptyCollections: self.omitEmptyCollections
    )
  }

  mutating func superEncoder() -> any Encoder {
    let idxKey = _DynamicCodingKey(intValue: self.count)!
    let childNode = EncodingNode()
    self.node.appendArrayEntry(.node(childNode))
    return InternalStructEncoder(
      node: childNode,
      codingPath: self.codingPath + [idxKey],
      omitEmptyCollections: self.omitEmptyCollections
    )
  }
}

fileprivate struct InternalSingleValueStructEncodingContainer: SingleValueEncodingContainer {
  let node: EncodingNode
  let codingPath: [any CodingKey]
  let omitEmptyCollections: Bool

  mutating func encodeNil() throws {
    self.node.storage = .singleValue(.null(WKTNullValue()))
  }

  mutating func encode(_ value: Bool) throws {
    self.node.storage = .singleValue(.bool(value))
  }

  mutating func encode(_ value: String) throws {
    self.node.storage = .singleValue(.string(value))
  }

  mutating func encode(_ value: Double) throws {
    self.node.storage = .singleValue(WKTStructEncoder.encodeDouble(value))
  }

  mutating func encode(_ value: Float) throws {
    self.node.storage = .singleValue(WKTStructEncoder.encodeFloat(value))
  }

  mutating func encode(_ value: Int) throws {
    self.node.storage = .singleValue(.number(Double(value)))
  }

  mutating func encode(_ value: Int8) throws {
    self.node.storage = .singleValue(.number(Double(value)))
  }

  mutating func encode(_ value: Int16) throws {
    self.node.storage = .singleValue(.number(Double(value)))
  }

  mutating func encode(_ value: Int32) throws {
    self.node.storage = .singleValue(.number(Double(value)))
  }

  mutating func encode(_ value: Int64) throws {
    self.node.storage = .singleValue(.string(String(value)))
  }

  mutating func encode(_ value: Int128) throws {
    self.node.storage = .singleValue(.string(String(value)))
  }

  mutating func encode(_ value: UInt) throws {
    self.node.storage = .singleValue(.number(Double(value)))
  }

  mutating func encode(_ value: UInt8) throws {
    self.node.storage = .singleValue(.number(Double(value)))
  }

  mutating func encode(_ value: UInt16) throws {
    self.node.storage = .singleValue(.number(Double(value)))
  }

  mutating func encode(_ value: UInt32) throws {
    self.node.storage = .singleValue(.number(Double(value)))
  }

  mutating func encode(_ value: UInt64) throws {
    self.node.storage = .singleValue(.string(String(value)))
  }

  mutating func encode(_ value: UInt128) throws {
    self.node.storage = .singleValue(.string(String(value)))
  }

  mutating func encode<T>(_ value: T) throws where T: Encodable {
    let encoded = try WKTStructEncoder.encodeToValue(
      value,
      codingPath: self.codingPath,
      omitEmptyCollections: self.omitEmptyCollections
    )
    self.node.storage = .singleValue(encoded)
  }
}
