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
import Testing

@testable @_spi(GoogleCloudInternal) import GoogleWKT

@Suite struct WKTStructCodableTests {
  struct AllPrimitivesMessage: Codable, Equatable, _AnyPackable, Sendable {
    var boolVal: Bool = false
    var intVal: Int = 0
    var int8Val: Int8 = 0
    var int16Val: Int16 = 0
    var int32Val: Int32 = 0
    var int64Val: Int64 = 0
    var uintVal: UInt = 0
    var uint8Val: UInt8 = 0
    var uint16Val: UInt16 = 0
    var uint32Val: UInt32 = 0
    var uint64Val: UInt64 = 0
    var floatVal: Float = 0
    var doubleVal: Double = 0
    var stringVal: String = ""
    var dataVal: Data = Data()

    static var _anyTypeUrl: String { "type.googleapis.com/test.AllPrimitivesMessage" }

    init(
      boolVal: Bool = false,
      intVal: Int = 0,
      int8Val: Int8 = 0,
      int16Val: Int16 = 0,
      int32Val: Int32 = 0,
      int64Val: Int64 = 0,
      uintVal: UInt = 0,
      uint8Val: UInt8 = 0,
      uint16Val: UInt16 = 0,
      uint32Val: UInt32 = 0,
      uint64Val: UInt64 = 0,
      floatVal: Float = 0,
      doubleVal: Double = 0,
      stringVal: String = "",
      dataVal: Data = Data()
    ) {
      self.boolVal = boolVal
      self.intVal = intVal
      self.int8Val = int8Val
      self.int16Val = int16Val
      self.int32Val = int32Val
      self.int64Val = int64Val
      self.uintVal = uintVal
      self.uint8Val = uint8Val
      self.uint16Val = uint16Val
      self.uint32Val = uint32Val
      self.uint64Val = uint64Val
      self.floatVal = floatVal
      self.doubleVal = doubleVal
      self.stringVal = stringVal
      self.dataVal = dataVal
    }

    init(fromAny any: WKTAny) throws {
      self = try _slowAnyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _slowAnySerialize(message: self)
    }
  }

  @Test func packAndUnpackAllPrimitives() throws {
    let original = AllPrimitivesMessage(
      boolVal: true,
      intVal: -42,
      int8Val: -8,
      int16Val: -16,
      int32Val: -32,
      int64Val: Int64.min,
      uintVal: 42,
      uint8Val: 8,
      uint16Val: 16,
      uint32Val: 32,
      uint64Val: UInt64.max,
      floatVal: 3.14,
      doubleVal: 2.718281828,
      stringVal: "hello world",
      dataVal: Data([0x01, 0x02, 0x03, 0xFF])
    )

    let packed = try original._pack()
    #expect(packed["boolVal"] == .bool(true))
    #expect(packed["intVal"] == .number(-42))
    #expect(packed["int8Val"] == .number(-8))
    #expect(packed["int16Val"] == .number(-16))
    #expect(packed["int32Val"] == .number(-32))
    #expect(packed["int64Val"] == .string(String(Int64.min)))
    #expect(packed["uintVal"] == .number(42))
    #expect(packed["uint8Val"] == .number(8))
    #expect(packed["uint16Val"] == .number(16))
    #expect(packed["uint32Val"] == .number(32))
    #expect(packed["uint64Val"] == .string(String(UInt64.max)))
    #expect(packed["floatVal"] == .number(3.14))
    #expect(packed["doubleVal"] == .number(2.718281828))
    #expect(packed["stringVal"] == .string("hello world"))
    #expect(packed["dataVal"] == .string(Data([0x01, 0x02, 0x03, 0xFF]).base64EncodedString()))

    let any = try WKTAny(fromMessage: original)
    let unpacked = try AllPrimitivesMessage(fromAny: any)
    #expect(unpacked == original)
  }

  @Test func packAndUnpackNonConformingFloats() throws {
    let infMsg = AllPrimitivesMessage(floatVal: .infinity, doubleVal: -.infinity)
    let infPacked = try infMsg._pack()
    #expect(infPacked["floatVal"] == .string("Infinity"))
    #expect(infPacked["doubleVal"] == .string("-Infinity"))

    let infAny = try WKTAny(fromMessage: infMsg)
    let infUnpacked = try AllPrimitivesMessage(fromAny: infAny)
    #expect(infUnpacked == infMsg)

    let nanMsg = AllPrimitivesMessage(floatVal: .nan, doubleVal: .nan)
    let nanPacked = try nanMsg._pack()
    #expect(nanPacked["floatVal"] == .string("NaN"))
    #expect(nanPacked["doubleVal"] == .string("NaN"))

    let nanAny = try WKTAny(fromMessage: nanMsg)
    let nanUnpacked = try AllPrimitivesMessage(fromAny: nanAny)
    #expect(nanUnpacked.floatVal.isNaN)
    #expect(nanUnpacked.doubleVal.isNaN)
  }

  @Test func decodeFlexibleStringAndNumericRepresentations() throws {
    let fields: WKTStruct = [
      "boolVal": .string("true"),
      "intVal": .string("-42"),
      "int8Val": .string("-8"),
      "int16Val": .string("-16"),
      "int32Val": .string("-32"),
      "int64Val": .number(64),
      "uintVal": .string("42"),
      "uint8Val": .string("8"),
      "uint16Val": .string("16"),
      "uint32Val": .string("32"),
      "uint64Val": .number(128),
      "floatVal": .string("1.5"),
      "doubleVal": .string("2.5"),
      "stringVal": .string("text"),
      "dataVal": .string(Data("abc".utf8).base64EncodedString()),
    ]
    let decoder = WKTStructDecoder()
    let decoded = try decoder.decode(AllPrimitivesMessage.self, from: fields)
    #expect(decoded.boolVal == true)
    #expect(decoded.intVal == -42)
    #expect(decoded.int8Val == -8)
    #expect(decoded.int16Val == -16)
    #expect(decoded.int32Val == -32)
    #expect(decoded.int64Val == 64)
    #expect(decoded.uintVal == 42)
    #expect(decoded.uint8Val == 8)
    #expect(decoded.uint16Val == 16)
    #expect(decoded.uint32Val == 32)
    #expect(decoded.uint64Val == 128)
    #expect(decoded.floatVal == 1.5)
    #expect(decoded.doubleVal == 2.5)
    #expect(decoded.stringVal == "text")
    #expect(decoded.dataVal == Data("abc".utf8))
  }

  @Test func decodeMissingFieldsDefaultsToZeroValues() throws {
    let decoder = WKTStructDecoder()
    let decoded = try decoder.decode(AllPrimitivesMessage.self, from: [:])
    #expect(decoded == AllPrimitivesMessage())
  }

  struct CollectionsAndOptionalsMessage: Codable, Equatable, _AnyPackable, Sendable {
    var optInt64: Int64? = nil
    var optUInt64: UInt64? = nil
    var optString: String? = nil
    var optData: Data? = nil
    var listInt64: [Int64] = []
    var mapInt64: [String: Int64] = [:]
    var structField: WKTStruct? = nil
    var listValueField: WKTListValue? = nil
    var valueField: WKTValue? = nil

    static var _anyTypeUrl: String { "type.googleapis.com/test.CollectionsAndOptionalsMessage" }

    enum CodingKeys: String, CodingKey {
      case optInt64
      case optUInt64
      case optString
      case optData
      case listInt64
      case mapInt64
      case structField
      case listValueField
      case valueField
    }

    init(
      optInt64: Int64? = nil,
      optUInt64: UInt64? = nil,
      optString: String? = nil,
      optData: Data? = nil,
      listInt64: [Int64] = [],
      mapInt64: [String: Int64] = [:],
      structField: WKTStruct? = nil,
      listValueField: WKTListValue? = nil,
      valueField: WKTValue? = nil
    ) {
      self.optInt64 = optInt64
      self.optUInt64 = optUInt64
      self.optString = optString
      self.optData = optData
      self.listInt64 = listInt64
      self.mapInt64 = mapInt64
      self.structField = structField
      self.listValueField = listValueField
      self.valueField = valueField
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.optInt64 = try container.decodeIfPresent(Int64.self, forKey: .optInt64)
      self.optUInt64 = try container.decodeIfPresent(UInt64.self, forKey: .optUInt64)
      self.optString = try container.decodeIfPresent(String.self, forKey: .optString)
      self.optData = try container.decodeIfPresent(Data.self, forKey: .optData)
      if let v = try container.decodeIfPresent([Int64].self, forKey: .listInt64) {
        self.listInt64 = v
      }
      if let v = try container.decodeIfPresent([String: Int64].self, forKey: .mapInt64) {
        self.mapInt64 = v
      }
      self.structField = try container.decodeIfPresent(WKTStruct.self, forKey: .structField)
      self.listValueField = try container.decodeIfPresent(
        WKTListValue.self, forKey: .listValueField)
      self.valueField = try container.decodeIfPresent(WKTValue.self, forKey: .valueField)
    }

    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encodeIfPresent(self.optInt64, forKey: .optInt64)
      try container.encodeIfPresent(self.optUInt64, forKey: .optUInt64)
      try container.encodeIfPresent(self.optString, forKey: .optString)
      try container.encodeIfPresent(self.optData, forKey: .optData)
      try container.encode(self.listInt64, forKey: .listInt64)
      try container.encode(self.mapInt64, forKey: .mapInt64)
      try container.encodeIfPresent(self.structField, forKey: .structField)
      try container.encodeIfPresent(self.listValueField, forKey: .listValueField)
      try container.encodeIfPresent(self.valueField, forKey: .valueField)
    }

    init(fromAny any: WKTAny) throws {
      self = try _slowAnyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _slowAnySerialize(message: self)
    }
  }

  @Test func omitEmptyCollectionsAndPreserveExplicitOptionalWKTCollections() throws {
    let emptyMsg = CollectionsAndOptionalsMessage()
    let emptyPacked = try emptyMsg._pack()
    #expect(emptyPacked.isEmpty)

    let presentEmptyWKT = CollectionsAndOptionalsMessage(
      structField: [:],
      listValueField: []
    )
    let presentPacked = try presentEmptyWKT._pack()
    #expect(presentPacked == ["structField": .object([:]), "listValueField": .array([])])
    let any = try WKTAny(fromMessage: presentEmptyWKT)
    let unpacked = try CollectionsAndOptionalsMessage(fromAny: any)
    #expect(unpacked == presentEmptyWKT)

    let populated = CollectionsAndOptionalsMessage(
      optInt64: 9_000_000_000,
      optUInt64: 18_000_000_000,
      optString: "present",
      optData: Data([0xAA, 0xBB]),
      listInt64: [1, 2, Int64.max],
      mapInt64: ["k": Int64.min],
      structField: ["nested": .bool(true)],
      listValueField: [.number(1), .string("two")],
      valueField: .string("val")
    )
    let popPacked = try populated._pack()
    #expect(popPacked["optInt64"] == .string("9000000000"))
    #expect(popPacked["optUInt64"] == .string("18000000000"))
    #expect(
      popPacked["listInt64"] == .array([.string("1"), .string("2"), .string(String(Int64.max))]))
    #expect(popPacked["mapInt64"] == .object(["k": .string(String(Int64.min))]))

    let popAny = try WKTAny(fromMessage: populated)
    let popUnpacked = try CollectionsAndOptionalsMessage(fromAny: popAny)
    #expect(popUnpacked == populated)
  }

  @Test func preserveEmptyCollectionsWhenDisabled() throws {
    let encoder = WKTStructEncoder(omitEmptyCollections: false)
    let msg = CollectionsAndOptionalsMessage()
    let packed = try encoder.encode(msg)
    #expect(packed["listInt64"] == .array([]))
    #expect(packed["mapInt64"] == .object([:]))
  }

  @Test func generatedWKTMessagesParityWithProtoJSON() throws {
    let option = WKTOption().with {
      $0.name = "custom_opt"
      $0.value = try? WKTAny(fromMessage: WKTDuration(seconds: 10, nanos: 500_000_000))
    }
    let field = WKTField().with {
      $0.kind = .typeString
      $0.cardinality = .optional
      $0.number = 1
      $0.name = "display_name"
      $0.jsonName = "displayName"
      $0.options = [option]
    }
    var api = WKTApi().with {
      $0.name = "google.example.v1.ExampleService"
      $0.version = "v1"
      $0.syntax = .proto3
      $0.sourceContext = WKTSourceContext().with { $0.fileName = "example.proto" }
      $0.methods = [
        WKTMethod().with {
          $0.name = "GetItem"
          $0.requestTypeUrl = "type.googleapis.com/google.example.v1.GetItemRequest"
          $0.responseTypeUrl = "type.googleapis.com/google.example.v1.Item"
          $0.requestStreaming = false
          $0.responseStreaming = false
          $0.options = [option]
          $0.syntax = .proto3
        }
      ]
      $0.options = [option]
    }
    api._unknownFields.json = [
      "extraStr": .string("extra"),
      "extraObj": .object(["inner": .number(42)]),
      "extraArr": .array([.bool(true), .null(WKTNullValue())]),
    ]

    let packedStruct = try api._pack()
    let jsonEncoder = _ProtoJSONEncoder()
    let jsonDecoder = _ProtoJSONDecoder()
    let expectedStruct = try jsonDecoder.decode(WKTStruct.self, from: try jsonEncoder.encode(api))
    #expect(packedStruct == expectedStruct)

    let any = try WKTAny(fromMessage: api)
    let unpackedApi = try WKTApi(fromAny: any)
    #expect(unpackedApi == api)

    let fieldAny = try WKTAny(fromMessage: field)
    let unpackedField = try WKTField(fromAny: fieldAny)
    #expect(unpackedField == field)
  }

  struct NestedAndSuperCodableMessage: Codable, Equatable {
    var nestedDictValue: String
    var nestedArrayValues: [Int32]
    var superValue: String

    enum CodingKeys: String, CodingKey {
      case nestedDict
      case nestedArray
      case customSuper
    }

    enum NestedKeys: String, CodingKey {
      case value
    }

    init(nestedDictValue: String, nestedArrayValues: [Int32], superValue: String) {
      self.nestedDictValue = nestedDictValue
      self.nestedArrayValues = nestedArrayValues
      self.superValue = superValue
    }

    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      let nestedDict = try container.nestedContainer(keyedBy: NestedKeys.self, forKey: .nestedDict)
      self.nestedDictValue = try nestedDict.decode(String.self, forKey: .value)

      var nestedArr = try container.nestedUnkeyedContainer(forKey: .nestedArray)
      var items: [Int32] = []
      while !nestedArr.isAtEnd {
        items.append(try nestedArr.decode(Int32.self))
      }
      self.nestedArrayValues = items

      let superDec = try container.superDecoder(forKey: .customSuper)
      self.superValue = try String(from: superDec)
    }

    func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      var nestedDict = container.nestedContainer(keyedBy: NestedKeys.self, forKey: .nestedDict)
      try nestedDict.encode(self.nestedDictValue, forKey: .value)

      var nestedArr = container.nestedUnkeyedContainer(forKey: .nestedArray)
      for item in self.nestedArrayValues {
        try nestedArr.encode(item)
      }

      let superEnc = container.superEncoder(forKey: .customSuper)
      try self.superValue.encode(to: superEnc)
    }
  }

  @Test func nestedContainersAndSuperEncoderDecoder() throws {
    let original = NestedAndSuperCodableMessage(
      nestedDictValue: "inside",
      nestedArrayValues: [10, 20, 30],
      superValue: "super-val"
    )
    let encoder = WKTStructEncoder()
    let encoded = try encoder.encode(original)
    #expect(
      encoded == [
        "nestedDict": .object(["value": .string("inside")]),
        "nestedArray": .array([.number(10), .number(20), .number(30)]),
        "customSuper": .string("super-val"),
      ]
    )

    let decoder = WKTStructDecoder()
    let decoded = try decoder.decode(NestedAndSuperCodableMessage.self, from: encoded)
    #expect(decoded == original)
  }

  @Test func invalidDecodingInputsThrowExpectedErrors() throws {
    let decoder = WKTStructDecoder()

    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(AllPrimitivesMessage.self, from: ["boolVal": .string("not-a-bool")])
    }
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(AllPrimitivesMessage.self, from: ["int32Val": .string("not-an-int")])
    }
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(AllPrimitivesMessage.self, from: ["int32Val": .number(3.14)])
    }
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(AllPrimitivesMessage.self, from: ["stringVal": .number(42)])
    }
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(
        AllPrimitivesMessage.self, from: ["dataVal": .string("!!!bad-base64!!!")])
    }
    #expect(throws: DecodingError.self) {
      _ = try decoder.decode(AllPrimitivesMessage.self, from: ["dataVal": .number(42)])
    }
  }

  @Test func invalidWKTValueNumberThrowsEncodingError() throws {
    let encoder = WKTStructEncoder()
    let msg = CollectionsAndOptionalsMessage(valueField: .number(.nan))
    #expect(throws: EncodingError.self) {
      _ = try encoder.encode(msg)
    }
    let nestedBadStruct = CollectionsAndOptionalsMessage(structField: ["bad": .number(.infinity)])
    #expect(throws: EncodingError.self) {
      _ = try encoder.encode(nestedBadStruct)
    }
    let nestedBadList = CollectionsAndOptionalsMessage(listValueField: [.number(-.infinity)])
    #expect(throws: EncodingError.self) {
      _ = try encoder.encode(nestedBadList)
    }
  }

  struct RecursiveNode: Codable, Equatable, _AnyPackable, Sendable {
    var name: String = ""
    var child: WKTRecursive<RecursiveNode>? = nil

    static var _anyTypeUrl: String { "type.googleapis.com/test.RecursiveNode" }

    init(name: String = "", child: WKTRecursive<RecursiveNode>? = nil) {
      self.name = name
      self.child = child
    }

    init(fromAny any: WKTAny) throws {
      self = try _slowAnyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _slowAnySerialize(message: self)
    }
  }

  @Test func recursiveMessagePackAndUnpack() throws {
    let leaf = RecursiveNode(name: "leaf")
    let root = RecursiveNode(name: "root", child: WKTRecursive(value: leaf))

    let any = try WKTAny(fromMessage: root)
    let unpacked = try RecursiveNode(fromAny: any)
    #expect(unpacked == root)
    #expect(unpacked.child?.value.name == "leaf")
  }

  @Test func topLevelNonObjectThrowsEncodingError() {
    let encoder = WKTStructEncoder()
    #expect(throws: EncodingError.self) {
      _ = try encoder.encode("not-an-object")
    }
    #expect(throws: EncodingError.self) {
      _ = try encoder.encode([1, 2, 3])
    }
  }

  @Test func directWKTStructAndValueDecodeFastPath() throws {
    let decoder = WKTStructDecoder()
    let input: WKTStruct = ["a": .string("hello"), "b": .number(123)]
    let decodedStruct = try decoder.decode(WKTStruct.self, from: input)
    #expect(decodedStruct == input)
    let decodedValue = try decoder.decode(WKTValue.self, from: input)
    #expect(decodedValue == .object(input))
  }
}
