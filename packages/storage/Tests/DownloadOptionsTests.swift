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
@testable import GoogleCloudStorage
import Testing

@Suite struct DownloadOptionsTests {
  @Test func readRangeHeaderValues() {
    #expect(ReadRange.entire.headerValue == nil)
    #expect(ReadRange.fromOffset(1024).headerValue == "bytes=1024-")
    #expect(ReadRange.prefix(500).headerValue == "bytes=0-499")
    #expect(ReadRange.prefix(0).headerValue == "bytes=0-0")
    #expect(ReadRange.suffix(100).headerValue == "bytes=-100")
    #expect(ReadRange.bounded(start: 10, end: 50).headerValue == "bytes=10-50")
    #expect(ReadRange(10...50).headerValue == "bytes=10-50")
    #expect(ReadRange(10...50) == ReadRange.bounded(start: 10, end: 50))
  }

  @Test func readObjectOptionsDefaultsAndWithBuilder() throws {
    let defaultOptions = ReadObjectOptions.default
    #expect(defaultOptions.generation == nil)
    #expect(defaultOptions.preconditions == nil)
    #expect(defaultOptions.customerEncryptionKey == nil)
    #expect(defaultOptions.range == .entire)
    #expect(defaultOptions.disableDecompressiveTranscoding == false)
    #expect(defaultOptions.checksums == .default)
    #expect(defaultOptions.autoResume == true)

    let preconditions = StoragePreconditions().with {
      $0.ifGenerationMatch = 123
    }
    let options = ReadObjectOptions().with {
      $0.generation = 456
      $0.preconditions = preconditions
      $0.range = .bounded(start: 0, end: 1024)
      $0.disableDecompressiveTranscoding = true
      $0.checksums = .none
      $0.autoResume = false
    }

    #expect(options.generation == 456)
    #expect(options.preconditions?.ifGenerationMatch == 123)
    #expect(options.range == .bounded(start: 0, end: 1024))
    #expect(options.disableDecompressiveTranscoding == true)
    #expect(options.checksums == .none)
    #expect(options.autoResume == false)
  }

  @Test func readObjectMetadataProperties() {
    let now = Date()
    let metadata = ReadObjectMetadata(
      bucket: "my-bucket",
      object: "my-object.txt",
      size: 2048,
      generation: 10,
      metageneration: 2,
      etag: "etag-123",
      crc32c: "crc-456",
      md5Hash: "md5-789",
      contentType: "text/plain",
      contentEncoding: "gzip",
      contentDisposition: "inline",
      storageClass: "STANDARD",
      updated: now
    )

    #expect(metadata.bucket == "my-bucket")
    #expect(metadata.object == "my-object.txt")
    #expect(metadata.size == 2048)
    #expect(metadata.generation == 10)
    #expect(metadata.metageneration == 2)
    #expect(metadata.etag == "etag-123")
    #expect(metadata.crc32c == "crc-456")
    #expect(metadata.md5Hash == "md5-789")
    #expect(metadata.contentType == "text/plain")
    #expect(metadata.contentEncoding == "gzip")
    #expect(metadata.contentDisposition == "inline")
    #expect(metadata.storageClass == "STANDARD")
    #expect(metadata.updated == now)
  }

  @Test func readObjectSequenceAndResponse() async throws {
    let metadata = ReadObjectMetadata(bucket: "bkt", object: "obj")
    let options = ReadObjectOptions().with { $0.autoResume = false }
    let sequence = ReadObjectSequence(bucket: "bkt", object: "obj", options: options)

    #expect(sequence.bucket == "bkt")
    #expect(sequence.object == "obj")
    #expect(sequence.options.autoResume == false)

    var iterator = sequence.makeAsyncIterator()
    let firstChunk = try await iterator.next()
    #expect(firstChunk == nil)

    let response = ReadObjectResponse(metadata: metadata, body: sequence)
    #expect(response.metadata.bucket == "bkt")
    #expect(response.metadata.object == "obj")
    #expect(response.body.bucket == "bkt")
  }

  @Test func downloadErrorEquality() {
    let err1 = DownloadError.checksumMismatch(expected: "a", actual: "b", algorithm: "crc32c")
    let err2 = DownloadError.checksumMismatch(expected: "a", actual: "b", algorithm: "crc32c")
    let err3 = DownloadError.invalidRange("bytes=1-0")

    #expect(err1 == err2)
    #expect(err1 != err3)
  }
}
