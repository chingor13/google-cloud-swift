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
      self = try _anyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _anySerialize(message: self)
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
    #expect(packed["floatVal"] == .number(Double(original.floatVal)))
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
      self = try _anyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _anySerialize(message: self)
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

    let fastStruct = try _anySerialize(message: api)
    let slowStruct = try _slowAnySerialize(message: api)
    #expect(fastStruct == slowStruct)

    let any = try WKTAny(fromMessage: api)
    let fastUnpackedApi = try _anyDeserialize(WKTApi.self, from: any)
    let slowUnpackedApi = try _slowAnyDeserialize(WKTApi.self, from: any)
    #expect(fastUnpackedApi == api)
    #expect(fastUnpackedApi == slowUnpackedApi)

    let fieldAny = try WKTAny(fromMessage: field)
    let fastUnpackedField = try _anyDeserialize(WKTField.self, from: fieldAny)
    let slowUnpackedField = try _slowAnyDeserialize(WKTField.self, from: fieldAny)
    #expect(fastUnpackedField == field)
    #expect(fastUnpackedField == slowUnpackedField)

    #expect(throws: WKTAnyError.mismatchedTypeURL) {
      _ = try _anyDeserialize(WKTField.self, from: any)
    }
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
      self = try _anyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _anySerialize(message: self)
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

  // Helper to construct a WKTAny from a raw JSON object string and a message type URL.
  private static func makeAny<M: _AnyPackable>(jsonObject: String, for type: M.Type) throws
    -> WKTAny
  {
    let decoder = _ProtoJSONDecoder()
    var fields = try decoder.decode(WKTStruct.self, from: Data(jsonObject.utf8))
    fields["@type"] = .string(M._anyTypeUrl)
    let encoder = _ProtoJSONEncoder()
    let data = try encoder.encode(fields)
    return try decoder.decode(WKTAny.self, from: data)
  }

  struct RequiredPrimitives: Codable, Equatable, _AnyPackable, Sendable {
    static var _anyTypeUrl: String { "type.googleapis.com/test.RequiredPrimitives" }

    var fieldBool: Bool = Bool()
    var fieldInt: Int = Int()
    var fieldInt32: Int32 = Int32()
    var fieldInt64: Int64 = Int64()
    var fieldUInt: UInt = UInt()
    var fieldUInt32: UInt32 = UInt32()
    var fieldUInt64: UInt64 = UInt64()
    var fieldFloat: Float = Float()
    var fieldDouble: Double = Double()
    var fieldString: String = String()
    var fieldData: Data = Data()

    func with(_ config: (inout Self) -> Void) -> Self {
      var copy = self
      config(&copy)
      return copy
    }

    init() {}

    init(fromAny any: WKTAny) throws {
      self = try _anyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _anySerialize(message: self)
    }
  }

  @Test(
    "anySerialize and anyDeserialize required primitives",
    arguments: [
      (#"{}"#, RequiredPrimitives()),
      (#"{"fieldBool":   true }"#, RequiredPrimitives().with { $0.fieldBool = true }),
      (#"{"fieldInt":    42   }"#, RequiredPrimitives().with { $0.fieldInt = 42 }),
      (#"{"fieldInt32":  42   }"#, RequiredPrimitives().with { $0.fieldInt32 = 42 }),
      (#"{"fieldInt64":  42   }"#, RequiredPrimitives().with { $0.fieldInt64 = 42 }),
      (#"{"fieldUInt":   42   }"#, RequiredPrimitives().with { $0.fieldUInt = 42 }),
      (#"{"fieldUInt32": 42   }"#, RequiredPrimitives().with { $0.fieldUInt32 = 42 }),
      (#"{"fieldUInt64": 42   }"#, RequiredPrimitives().with { $0.fieldUInt64 = 42 }),
      (#"{"fieldFloat":  42   }"#, RequiredPrimitives().with { $0.fieldFloat = 42 }),
      (#"{"fieldDouble": 42   }"#, RequiredPrimitives().with { $0.fieldDouble = 42 }),
      (#"{"fieldString": "42" }"#, RequiredPrimitives().with { $0.fieldString = "42" }),
      (
        #"{"fieldData":   "NDI=" }"#,
        RequiredPrimitives().with { $0.fieldData = Data(base64Encoded: "NDI=")! }
      ),
      (#"{"fieldBool":   "true" }"#, RequiredPrimitives().with { $0.fieldBool = true }),
      (#"{"fieldInt":    "42"   }"#, RequiredPrimitives().with { $0.fieldInt = 42 }),
      (#"{"fieldInt32":  "42"   }"#, RequiredPrimitives().with { $0.fieldInt32 = 42 }),
      (#"{"fieldInt64":  "42"   }"#, RequiredPrimitives().with { $0.fieldInt64 = 42 }),
      (#"{"fieldUInt":   "42"   }"#, RequiredPrimitives().with { $0.fieldUInt = 42 }),
      (#"{"fieldUInt32": "42"   }"#, RequiredPrimitives().with { $0.fieldUInt32 = 42 }),
      (#"{"fieldUInt64": "42"   }"#, RequiredPrimitives().with { $0.fieldUInt64 = 42 }),
      (#"{"fieldFloat":  "42"   }"#, RequiredPrimitives().with { $0.fieldFloat = 42 }),
      (#"{"fieldDouble": "42"   }"#, RequiredPrimitives().with { $0.fieldDouble = 42 }),
    ]
  )
  func requiredPrimitivesParity(input: String, want: RequiredPrimitives) throws {
    let any = try Self.makeAny(jsonObject: input, for: RequiredPrimitives.self)
    let fastGot = try _anyDeserialize(RequiredPrimitives.self, from: any)
    let slowGot = try _slowAnyDeserialize(RequiredPrimitives.self, from: any)
    #expect(fastGot == want)
    #expect(fastGot == slowGot)

    let fastPacked = try _anySerialize(message: want)
    let slowPacked = try _slowAnySerialize(message: want)
    #expect(fastPacked == slowPacked)
  }

  @Test(
    "anyDeserialize required bad inputs",
    arguments: [
      #"{"fieldBool":   "bad" }"#,
      #"{"fieldInt":    "bad" }"#,
      #"{"fieldInt32":  "bad" }"#,
      #"{"fieldInt64":  "bad" }"#,
      #"{"fieldUInt":   "bad" }"#,
      #"{"fieldUInt32": "bad" }"#,
      #"{"fieldUInt64": "bad" }"#,
      #"{"fieldFloat":  "bad" }"#,
      #"{"fieldDouble": "bad" }"#,
      #"{"fieldData":   "bad" }"#,
    ]
  )
  func requiredPrimitivesBadInputs(input: String) throws {
    let any = try Self.makeAny(jsonObject: input, for: RequiredPrimitives.self)
    let error = #expect(throws: DecodingError.self) {
      _ = try _anyDeserialize(RequiredPrimitives.self, from: any)
    }
    #expect({ if case .dataCorrupted = error { true } else { false } }())
  }

  @Test func requiredPrimitivesBadString() throws {
    let any = try Self.makeAny(jsonObject: #"{"fieldString": 42 }"#, for: RequiredPrimitives.self)
    let error = #expect(throws: DecodingError.self) {
      _ = try _anyDeserialize(RequiredPrimitives.self, from: any)
    }
    #expect({ if case .typeMismatch = error { true } else { false } }())
  }

  struct OptionalPrimitives: Codable, Equatable, _AnyPackable, Sendable {
    static var _anyTypeUrl: String { "type.googleapis.com/test.OptionalPrimitives" }

    var fieldBool: Bool? = nil
    var fieldInt: Int? = nil
    var fieldInt32: Int32? = nil
    var fieldInt64: Int64? = nil
    var fieldUInt: UInt? = nil
    var fieldUInt32: UInt32? = nil
    var fieldUInt64: UInt64? = nil
    var fieldFloat: Float? = nil
    var fieldDouble: Double? = nil
    var fieldString: String? = nil
    var fieldData: Data? = nil

    func with(_ config: (inout Self) -> Void) -> Self {
      var copy = self
      config(&copy)
      return copy
    }

    init() {}

    init(fromAny any: WKTAny) throws {
      self = try _anyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _anySerialize(message: self)
    }
  }

  @Test(
    "anySerialize and anyDeserialize optional primitives",
    arguments: [
      (#"{}"#, OptionalPrimitives()),
      (#"{"fieldBool":   null }"#, OptionalPrimitives()),
      (#"{"fieldInt":    null }"#, OptionalPrimitives()),
      (#"{"fieldInt32":  null }"#, OptionalPrimitives()),
      (#"{"fieldInt64":  null }"#, OptionalPrimitives()),
      (#"{"fieldUInt":   null }"#, OptionalPrimitives()),
      (#"{"fieldUInt32": null }"#, OptionalPrimitives()),
      (#"{"fieldUInt64": null }"#, OptionalPrimitives()),
      (#"{"fieldFloat":  null }"#, OptionalPrimitives()),
      (#"{"fieldDouble": null }"#, OptionalPrimitives()),
      (#"{"fieldString": null }"#, OptionalPrimitives()),
      (#"{"fieldData":   null }"#, OptionalPrimitives()),
      (#"{"fieldBool":   true }"#, OptionalPrimitives().with { $0.fieldBool = true }),
      (#"{"fieldInt":    42   }"#, OptionalPrimitives().with { $0.fieldInt = 42 }),
      (#"{"fieldInt32":  42   }"#, OptionalPrimitives().with { $0.fieldInt32 = 42 }),
      (#"{"fieldInt64":  42   }"#, OptionalPrimitives().with { $0.fieldInt64 = 42 }),
      (#"{"fieldUInt":   42   }"#, OptionalPrimitives().with { $0.fieldUInt = 42 }),
      (#"{"fieldUInt32": 42   }"#, OptionalPrimitives().with { $0.fieldUInt32 = 42 }),
      (#"{"fieldUInt64": 42   }"#, OptionalPrimitives().with { $0.fieldUInt64 = 42 }),
      (#"{"fieldFloat":  42   }"#, OptionalPrimitives().with { $0.fieldFloat = 42 }),
      (#"{"fieldDouble": 42   }"#, OptionalPrimitives().with { $0.fieldDouble = 42 }),
      (#"{"fieldString": "42" }"#, OptionalPrimitives().with { $0.fieldString = "42" }),
      (
        #"{"fieldData":   "NDI=" }"#,
        OptionalPrimitives().with { $0.fieldData = Data(base64Encoded: "NDI=")! }
      ),
      (#"{"fieldBool":   "true" }"#, OptionalPrimitives().with { $0.fieldBool = true }),
      (#"{"fieldInt":    "42"   }"#, OptionalPrimitives().with { $0.fieldInt = 42 }),
      (#"{"fieldInt32":  "42"   }"#, OptionalPrimitives().with { $0.fieldInt32 = 42 }),
      (#"{"fieldInt64":  "42"   }"#, OptionalPrimitives().with { $0.fieldInt64 = 42 }),
      (#"{"fieldUInt":   "42"   }"#, OptionalPrimitives().with { $0.fieldUInt = 42 }),
      (#"{"fieldUInt32": "42"   }"#, OptionalPrimitives().with { $0.fieldUInt32 = 42 }),
      (#"{"fieldUInt64": "42"   }"#, OptionalPrimitives().with { $0.fieldUInt64 = 42 }),
      (#"{"fieldFloat":  "42"   }"#, OptionalPrimitives().with { $0.fieldFloat = 42 }),
      (#"{"fieldDouble": "42"   }"#, OptionalPrimitives().with { $0.fieldDouble = 42 }),
    ]
  )
  func optionalPrimitivesParity(input: String, want: OptionalPrimitives) throws {
    let any = try Self.makeAny(jsonObject: input, for: OptionalPrimitives.self)
    let fastGot = try _anyDeserialize(OptionalPrimitives.self, from: any)
    let slowGot = try _slowAnyDeserialize(OptionalPrimitives.self, from: any)
    #expect(fastGot == want)
    #expect(fastGot == slowGot)

    let fastPacked = try _anySerialize(message: want)
    let slowPacked = try _slowAnySerialize(message: want)
    #expect(fastPacked == slowPacked)
  }

  @Test(
    "anyDeserialize optional bad inputs",
    arguments: [
      #"{"fieldBool":   "bad" }"#,
      #"{"fieldInt":    "bad" }"#,
      #"{"fieldInt32":  "bad" }"#,
      #"{"fieldInt64":  "bad" }"#,
      #"{"fieldUInt":   "bad" }"#,
      #"{"fieldUInt32": "bad" }"#,
      #"{"fieldUInt64": "bad" }"#,
      #"{"fieldFloat":  "bad" }"#,
      #"{"fieldDouble": "bad" }"#,
      #"{"fieldData":   "bad" }"#,
    ]
  )
  func optionalPrimitivesBadInputs(input: String) throws {
    let any = try Self.makeAny(jsonObject: input, for: OptionalPrimitives.self)
    let error = #expect(throws: DecodingError.self) {
      _ = try _anyDeserialize(OptionalPrimitives.self, from: any)
    }
    #expect({ if case .dataCorrupted = error { true } else { false } }())
  }

  @Test func optionalPrimitivesBadString() throws {
    let any = try Self.makeAny(jsonObject: #"{"fieldString": 42 }"#, for: OptionalPrimitives.self)
    let error = #expect(throws: DecodingError.self) {
      _ = try _anyDeserialize(OptionalPrimitives.self, from: any)
    }
    #expect({ if case .typeMismatch = error { true } else { false } }())
  }

  struct RepeatedPrimitives: Codable, Equatable, _AnyPackable, Sendable {
    static var _anyTypeUrl: String { "type.googleapis.com/test.RepeatedPrimitives" }

    var fieldBool: [Bool] = []
    var fieldInt: [Int] = []
    var fieldInt32: [Int32] = []
    var fieldInt64: [Int64] = []
    var fieldUInt: [UInt] = []
    var fieldUInt32: [UInt32] = []
    var fieldUInt64: [UInt64] = []
    var fieldFloat: [Float] = []
    var fieldDouble: [Double] = []
    var fieldString: [String] = []
    var fieldData: [Data] = []

    func with(_ config: (inout Self) -> Void) -> Self {
      var copy = self
      config(&copy)
      return copy
    }

    init() {}

    init(fromAny any: WKTAny) throws {
      self = try _anyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _anySerialize(message: self)
    }
  }

  @Test(
    "anySerialize and anyDeserialize repeated primitives",
    arguments: [
      (#"{}"#, RepeatedPrimitives()),
      (#"{"fieldBool":   []       }"#, RepeatedPrimitives()),
      (#"{"fieldInt":    []       }"#, RepeatedPrimitives()),
      (#"{"fieldInt32":  []       }"#, RepeatedPrimitives()),
      (#"{"fieldInt64":  []       }"#, RepeatedPrimitives()),
      (#"{"fieldUInt":   []       }"#, RepeatedPrimitives()),
      (#"{"fieldUInt32": []       }"#, RepeatedPrimitives()),
      (#"{"fieldUInt64": []       }"#, RepeatedPrimitives()),
      (#"{"fieldFloat":  []       }"#, RepeatedPrimitives()),
      (#"{"fieldDouble": []       }"#, RepeatedPrimitives()),
      (#"{"fieldString": []       }"#, RepeatedPrimitives()),
      (#"{"fieldData":   []       }"#, RepeatedPrimitives()),
      (#"{"fieldBool":   [true]   }"#, RepeatedPrimitives().with { $0.fieldBool = [true] }),
      (#"{"fieldInt":    [42]     }"#, RepeatedPrimitives().with { $0.fieldInt = [42] }),
      (#"{"fieldInt32":  [42]     }"#, RepeatedPrimitives().with { $0.fieldInt32 = [42] }),
      (#"{"fieldInt64":  [42]     }"#, RepeatedPrimitives().with { $0.fieldInt64 = [42] }),
      (#"{"fieldUInt":   [42]     }"#, RepeatedPrimitives().with { $0.fieldUInt = [42] }),
      (#"{"fieldUInt32": [42]     }"#, RepeatedPrimitives().with { $0.fieldUInt32 = [42] }),
      (#"{"fieldUInt64": [42]     }"#, RepeatedPrimitives().with { $0.fieldUInt64 = [42] }),
      (#"{"fieldFloat":  [42]     }"#, RepeatedPrimitives().with { $0.fieldFloat = [42] }),
      (#"{"fieldDouble": [42]     }"#, RepeatedPrimitives().with { $0.fieldDouble = [42] }),
      (#"{"fieldString": [""]     }"#, RepeatedPrimitives().with { $0.fieldString = [""] }),
      (#"{"fieldData":   [""]     }"#, RepeatedPrimitives().with { $0.fieldData = [Data()] }),
      (#"{"fieldBool":   ["true"] }"#, RepeatedPrimitives().with { $0.fieldBool = [true] }),
      (#"{"fieldInt":    ["42"]   }"#, RepeatedPrimitives().with { $0.fieldInt = [42] }),
      (#"{"fieldInt32":  ["42"]   }"#, RepeatedPrimitives().with { $0.fieldInt32 = [42] }),
      (#"{"fieldInt64":  ["42"]   }"#, RepeatedPrimitives().with { $0.fieldInt64 = [42] }),
      (#"{"fieldUInt":   ["42"]   }"#, RepeatedPrimitives().with { $0.fieldUInt = [42] }),
      (#"{"fieldUInt32": ["42"]   }"#, RepeatedPrimitives().with { $0.fieldUInt32 = [42] }),
      (#"{"fieldUInt64": ["42"]   }"#, RepeatedPrimitives().with { $0.fieldUInt64 = [42] }),
      (#"{"fieldFloat":  ["42"]   }"#, RepeatedPrimitives().with { $0.fieldFloat = [42] }),
      (#"{"fieldDouble": ["42"]   }"#, RepeatedPrimitives().with { $0.fieldDouble = [42] }),
      (#"{"fieldString": ["42"]   }"#, RepeatedPrimitives().with { $0.fieldString = ["42"] }),
      (
        #"{"fieldData":   ["NDI="] }"#,
        RepeatedPrimitives().with { $0.fieldData = [Data(base64Encoded: "NDI=")!] }
      ),
    ]
  )
  func repeatedPrimitivesParity(input: String, want: RepeatedPrimitives) throws {
    let any = try Self.makeAny(jsonObject: input, for: RepeatedPrimitives.self)
    let fastGot = try _anyDeserialize(RepeatedPrimitives.self, from: any)
    let slowGot = try _slowAnyDeserialize(RepeatedPrimitives.self, from: any)
    #expect(fastGot == want)
    #expect(fastGot == slowGot)

    let fastPacked = try _anySerialize(message: want)
    let slowPacked = try _slowAnySerialize(message: want)
    #expect(fastPacked == slowPacked)
  }

  @Test(
    "anyDeserialize repeated bad inputs",
    arguments: [
      #"{"fieldBool":   ["bad"] }"#,
      #"{"fieldInt":    ["bad"] }"#,
      #"{"fieldInt32":  ["bad"] }"#,
      #"{"fieldInt64":  ["bad"] }"#,
      #"{"fieldUInt":   ["bad"] }"#,
      #"{"fieldUInt32": ["bad"] }"#,
      #"{"fieldUInt64": ["bad"] }"#,
      #"{"fieldFloat":  ["bad"] }"#,
      #"{"fieldDouble": ["bad"] }"#,
      #"{"fieldData":   ["bad"] }"#,
    ]
  )
  func repeatedPrimitivesBadInputs(input: String) throws {
    let any = try Self.makeAny(jsonObject: input, for: RepeatedPrimitives.self)
    let error = #expect(throws: DecodingError.self) {
      _ = try _anyDeserialize(RepeatedPrimitives.self, from: any)
    }
    #expect({ if case .dataCorrupted = error { true } else { false } }())
  }

  @Test func repeatedPrimitivesBadString() throws {
    let any = try Self.makeAny(jsonObject: #"{"fieldData": [42] }"#, for: RepeatedPrimitives.self)
    let error = #expect(throws: DecodingError.self) {
      _ = try _anyDeserialize(RepeatedPrimitives.self, from: any)
    }
    #expect({ if case .typeMismatch = error { true } else { false } }())
  }

  struct MapPrimitives: Codable, Equatable, _AnyPackable, Sendable {
    static var _anyTypeUrl: String { "type.googleapis.com/test.MapPrimitives" }

    var fieldBool: [String: Bool] = [:]
    var fieldInt: [String: Int] = [:]
    var fieldInt32: [String: Int32] = [:]
    var fieldInt64: [String: Int64] = [:]
    var fieldUInt: [String: UInt] = [:]
    var fieldUInt32: [String: UInt32] = [:]
    var fieldUInt64: [String: UInt64] = [:]
    var fieldFloat: [String: Float] = [:]
    var fieldDouble: [String: Double] = [:]
    var fieldString: [String: String] = [:]
    var fieldData: [String: Data] = [:]

    func with(_ config: (inout Self) -> Void) -> Self {
      var copy = self
      config(&copy)
      return copy
    }

    init() {}

    init(fromAny any: WKTAny) throws {
      self = try _anyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _anySerialize(message: self)
    }
  }

  @Test(
    "anySerialize and anyDeserialize map primitives",
    arguments: [
      (#"{}"#, MapPrimitives()),
      (#"{"fieldBool":   {}       }"#, MapPrimitives()),
      (#"{"fieldInt":    {}       }"#, MapPrimitives()),
      (#"{"fieldInt32":  {}       }"#, MapPrimitives()),
      (#"{"fieldInt64":  {}       }"#, MapPrimitives()),
      (#"{"fieldUInt":   {}       }"#, MapPrimitives()),
      (#"{"fieldUInt32": {}       }"#, MapPrimitives()),
      (#"{"fieldUInt64": {}       }"#, MapPrimitives()),
      (#"{"fieldFloat":  {}       }"#, MapPrimitives()),
      (#"{"fieldDouble": {}       }"#, MapPrimitives()),
      (#"{"fieldString": {}       }"#, MapPrimitives()),
      (#"{"fieldData":   {}       }"#, MapPrimitives()),
      (#"{"fieldBool":   {"a": true}   }"#, MapPrimitives().with { $0.fieldBool = ["a": true] }),
      (#"{"fieldInt":    {"a": 42}     }"#, MapPrimitives().with { $0.fieldInt = ["a": 42] }),
      (#"{"fieldInt32":  {"a": 42}     }"#, MapPrimitives().with { $0.fieldInt32 = ["a": 42] }),
      (#"{"fieldInt64":  {"a": 42}     }"#, MapPrimitives().with { $0.fieldInt64 = ["a": 42] }),
      (#"{"fieldUInt":   {"a": 42}     }"#, MapPrimitives().with { $0.fieldUInt = ["a": 42] }),
      (#"{"fieldUInt32": {"a": 42}     }"#, MapPrimitives().with { $0.fieldUInt32 = ["a": 42] }),
      (#"{"fieldUInt64": {"a": 42}     }"#, MapPrimitives().with { $0.fieldUInt64 = ["a": 42] }),
      (#"{"fieldFloat":  {"a": 42}     }"#, MapPrimitives().with { $0.fieldFloat = ["a": 42] }),
      (#"{"fieldDouble": {"a": 42}     }"#, MapPrimitives().with { $0.fieldDouble = ["a": 42] }),
      (#"{"fieldString": {"a": ""}     }"#, MapPrimitives().with { $0.fieldString = ["a": ""] }),
      (#"{"fieldData":   {"a": ""}     }"#, MapPrimitives().with { $0.fieldData = ["a": Data()] }),
      (#"{"fieldBool":   {"a": "true"} }"#, MapPrimitives().with { $0.fieldBool = ["a": true] }),
      (#"{"fieldInt":    {"a": "42"}   }"#, MapPrimitives().with { $0.fieldInt = ["a": 42] }),
      (#"{"fieldInt32":  {"a": "42"}   }"#, MapPrimitives().with { $0.fieldInt32 = ["a": 42] }),
      (#"{"fieldInt64":  {"a": "42"}   }"#, MapPrimitives().with { $0.fieldInt64 = ["a": 42] }),
      (#"{"fieldUInt":   {"a": "42"}   }"#, MapPrimitives().with { $0.fieldUInt = ["a": 42] }),
      (#"{"fieldUInt32": {"a": "42"}   }"#, MapPrimitives().with { $0.fieldUInt32 = ["a": 42] }),
      (#"{"fieldUInt64": {"a": "42"}   }"#, MapPrimitives().with { $0.fieldUInt64 = ["a": 42] }),
      (#"{"fieldFloat":  {"a": "42"}   }"#, MapPrimitives().with { $0.fieldFloat = ["a": 42] }),
      (#"{"fieldDouble": {"a": "42"}   }"#, MapPrimitives().with { $0.fieldDouble = ["a": 42] }),
      (#"{"fieldString": {"a": "42"}   }"#, MapPrimitives().with { $0.fieldString = ["a": "42"] }),
      (
        #"{"fieldData":  {"a": "NDI="} }"#,
        MapPrimitives().with { $0.fieldData = ["a": Data(base64Encoded: "NDI=")!] }
      ),
    ]
  )
  func mapPrimitivesParity(input: String, want: MapPrimitives) throws {
    let any = try Self.makeAny(jsonObject: input, for: MapPrimitives.self)
    let fastGot = try _anyDeserialize(MapPrimitives.self, from: any)
    let slowGot = try _slowAnyDeserialize(MapPrimitives.self, from: any)
    #expect(fastGot == want)
    #expect(fastGot == slowGot)

    let fastPacked = try _anySerialize(message: want)
    let slowPacked = try _slowAnySerialize(message: want)
    #expect(fastPacked == slowPacked)
  }

  @Test(
    "anyDeserialize map bad inputs",
    arguments: [
      #"{"fieldBool":   {"a": "bad"} }"#,
      #"{"fieldInt":    {"a": "bad"} }"#,
      #"{"fieldInt32":  {"a": "bad"} }"#,
      #"{"fieldInt64":  {"a": "bad"} }"#,
      #"{"fieldUInt":   {"a": "bad"} }"#,
      #"{"fieldUInt32": {"a": "bad"} }"#,
      #"{"fieldUInt64": {"a": "bad"} }"#,
      #"{"fieldFloat":  {"a": "bad"} }"#,
      #"{"fieldDouble": {"a": "bad"} }"#,
      #"{"fieldData":   {"a": "bad"} }"#,
    ]
  )
  func mapPrimitivesBadInputs(input: String) throws {
    let any = try Self.makeAny(jsonObject: input, for: MapPrimitives.self)
    let error = #expect(throws: DecodingError.self) {
      _ = try _anyDeserialize(MapPrimitives.self, from: any)
    }
    #expect({ if case .dataCorrupted = error { true } else { false } }())
  }

  @Test func mapPrimitivesBadString() throws {
    let any = try Self.makeAny(jsonObject: #"{"fieldData": {"a": 42} }"#, for: MapPrimitives.self)
    let error = #expect(throws: DecodingError.self) {
      _ = try _anyDeserialize(MapPrimitives.self, from: any)
    }
    #expect({ if case .typeMismatch = error { true } else { false } }())
  }

  struct MessageWithRepeated: Codable, Equatable, _AnyPackable, Sendable {
    static var _anyTypeUrl: String { "type.googleapis.com/test.MessageWithRepeated" }

    var repeatedMessage: [MapPrimitives] = []
    var repeatedString: [String] = []
    var repeatedData: [Data] = []
    var repeatedNested: [RequiredPrimitives] = []

    init(
      repeatedMessage: [MapPrimitives] = [],
      repeatedString: [String] = [],
      repeatedData: [Data] = [],
      repeatedNested: [RequiredPrimitives] = []
    ) {
      self.repeatedMessage = repeatedMessage
      self.repeatedString = repeatedString
      self.repeatedData = repeatedData
      self.repeatedNested = repeatedNested
    }

    init(fromAny any: WKTAny) throws {
      self = try _anyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _anySerialize(message: self)
    }
  }

  @Test func decodeMissingMapNestedParity() throws {
    let input = #"{"repeatedMessage": [{}, {}]}"#
    let any = try Self.makeAny(jsonObject: input, for: MessageWithRepeated.self)
    let want = MessageWithRepeated(repeatedMessage: [MapPrimitives(), MapPrimitives()])
    let fastGot = try _anyDeserialize(MessageWithRepeated.self, from: any)
    let slowGot = try _slowAnyDeserialize(MessageWithRepeated.self, from: any)
    #expect(fastGot == want)
    #expect(fastGot == slowGot)

    let fastPacked = try _anySerialize(message: want)
    let slowPacked = try _slowAnySerialize(message: want)
    #expect(fastPacked == slowPacked)
  }

  struct CollectionMatrixMessage: Codable, Equatable, _AnyPackable, Sendable {
    static var _anyTypeUrl: String { "type.googleapis.com/test.CollectionMatrixMessage" }

    var name: String = "test"
    var emptyList: [String] = []
    var populatedList: [String] = ["a", "b"]
    var emptyMap: [String: String] = [:]
    var populatedMap: [String: String] = ["k": "v"]
    var matrix: [[Int]] = [[], [1, 2]]

    init() {}

    init(fromAny any: WKTAny) throws {
      self = try _anyDeserialize(Self.self, from: any)
    }

    func _pack() throws -> WKTStruct {
      return try _anySerialize(message: self)
    }
  }

  @Test func collectionMatrixParity() throws {
    let model = CollectionMatrixMessage()
    let fastPacked = try _anySerialize(message: model)
    let slowPacked = try _slowAnySerialize(message: model)
    #expect(fastPacked == slowPacked)

    let any = try WKTAny(fromMessage: model)
    let fastUnpacked = try _anyDeserialize(CollectionMatrixMessage.self, from: any)
    let slowUnpacked = try _slowAnyDeserialize(CollectionMatrixMessage.self, from: any)
    #expect(fastUnpacked == model)
    #expect(fastUnpacked == slowUnpacked)
  }

  @Test func allGeneratedWKTMessagesParity() throws {
    let sourceContext = WKTSourceContext().with {
      $0.fileName = "google/protobuf/type.proto"
    }
    let option = WKTOption().with {
      $0.name = "deprecated"
      $0.value = try? WKTAny(fromMessage: true)
    }
    let enumValue = WKTEnumValue().with {
      $0.name = "ENUM_VALUE_ONE"
      $0.number = 1
      $0.options = [option]
    }
    let wktEnum = WKTEnum().with {
      $0.name = "SampleEnum"
      $0.enumvalue = [enumValue]
      $0.options = [option]
      $0.sourceContext = sourceContext
      $0.syntax = .proto3
      $0.edition = "2023"
    }
    let field = WKTField().with {
      $0.kind = .typeMessage
      $0.cardinality = .repeated
      $0.number = 2
      $0.name = "items"
      $0.typeUrl = "type.googleapis.com/google.protobuf.Value"
      $0.oneofIndex = 1
      $0.packed = true
      $0.options = [option]
      $0.jsonName = "items"
      $0.defaultValue = ""
    }
    let wktType = WKTType().with {
      $0.name = "SampleType"
      $0.fields = [field]
      $0.oneofs = ["choice"]
      $0.options = [option]
      $0.sourceContext = sourceContext
      $0.syntax = .proto3
      $0.edition = "2023"
    }
    let method = WKTMethod().with {
      $0.name = "ListItems"
      $0.requestTypeUrl = "type.googleapis.com/google.protobuf.Empty"
      $0.requestStreaming = false
      $0.responseTypeUrl = "type.googleapis.com/google.protobuf.Struct"
      $0.responseStreaming = true
      $0.options = [option]
      $0.syntax = .proto3
    }
    let mixin = WKTMixin().with {
      $0.name = "google.cloud.location.Locations"
      $0.root = "google.cloud.location"
    }
    let api = WKTApi().with {
      $0.name = "google.example.Service"
      $0.methods = [method]
      $0.options = [option]
      $0.version = "v1"
      $0.sourceContext = sourceContext
      $0.mixins = [mixin]
      $0.syntax = .proto3
    }

    func verifyParity<M: Codable & Equatable & _AnyPackable>(_ message: M) throws {
      let fastPacked = try _anySerialize(message: message)
      let slowPacked = try _slowAnySerialize(message: message)
      #expect(fastPacked == slowPacked)

      let any = try WKTAny(fromMessage: message)
      let fastUnpacked = try _anyDeserialize(M.self, from: any)
      let slowUnpacked = try _slowAnyDeserialize(M.self, from: any)
      #expect(fastUnpacked == message)
      #expect(fastUnpacked == slowUnpacked)
    }

    try verifyParity(sourceContext)
    try verifyParity(option)
    try verifyParity(enumValue)
    try verifyParity(wktEnum)
    try verifyParity(field)
    try verifyParity(wktType)
    try verifyParity(method)
    try verifyParity(mixin)
    try verifyParity(api)
  }
}
