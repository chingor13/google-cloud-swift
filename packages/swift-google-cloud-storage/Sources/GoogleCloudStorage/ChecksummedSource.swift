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

struct ChunkInfo: Sendable {
  let data: ByteBuffer
  let isLast: Bool
  let checksum: String?
}

struct ChecksummedSource<S: UploadSource> {
  var source: S
  let options: ChecksumOptions
  private var calculators: [any ChecksumCalculator] = []
  private var bytesHashed: Int64 = 0
  private var currentOffset: Int64 = 0
  private var finalizedChecksum: String? = nil

  init(source: S, options: ChecksumOptions) {
    self.source = source
    self.options = options
    self.calculators = options.makeUploadCalculators()
  }

  init(source: S, validation: ChecksumValidation) {
    self.source = source
    switch validation {
    case .none:
      self.options = .none
    case .crc32c:
      self.options = ChecksumOptions(crc32c: .auto, md5: nil)
    case .md5:
      self.options = ChecksumOptions(crc32c: nil, md5: .auto)
    }
    self.calculators = self.options.makeUploadCalculators()
  }

  mutating func seedCRC32C(seed: UInt32, bytesHashed: Int64) {
    if let idx = calculators.firstIndex(where: { $0 is CRC32CCalculator }) {
      calculators[idx] = CRC32CCalculator(seed: seed)
      self.bytesHashed = bytesHashed
      self.currentOffset = bytesHashed
    }
  }

  private mutating func updateChecksums(data: ByteBuffer, startOffset: Int64) {
    guard !calculators.isEmpty else { return }

    let endOffset = startOffset + Int64(data.count)
    guard endOffset > bytesHashed else { return }

    let unhashedData: ByteBuffer
    if startOffset >= bytesHashed {
      unhashedData = data
    } else {
      let offsetInChunk = Int(bytesHashed - startOffset)
      unhashedData = data.subdata(in: offsetInChunk..<data.count)
    }

    for i in calculators.indices {
      calculators[i].update(unhashedData)
    }

    bytesHashed = endOffset
  }

  mutating func readChunk(maxBytes: Int) async throws -> ChunkInfo? {
    guard let chunk = try await source.read(maxBytes: maxBytes), !chunk.isEmpty else {
      return nil
    }

    let chunkOffset = currentOffset
    currentOffset += Int64(chunk.count)
    updateChecksums(data: chunk, startOffset: chunkOffset)

    let isLast = source.totalSize.map { currentOffset >= $0 } ?? false
    let checksum = isLast ? finalizeChecksum() : nil
    return ChunkInfo(data: chunk, isLast: isLast, checksum: checksum)
  }

  mutating func finalizeChecksum() -> String? {
    if let finalized = finalizedChecksum {
      return finalized
    }
    guard !calculators.isEmpty else { return nil }
    let result = calculators.map { "\($0.algorithmName)=\($0.finalize())" }.joined(separator: ", ")
    finalizedChecksum = result
    return result
  }
}

extension ChecksummedSource where S: SeekableUploadSource {
  mutating func seek(to offset: Int64) async throws {
    finalizedChecksum = nil
    currentOffset = offset

    guard offset > bytesHashed && !calculators.isEmpty else {
      try await source.seek(to: offset)
      return
    }

    // Catch up checksum calculation from `bytesHashed` to `offset`
    try await source.seek(to: bytesHashed)
    var currentSeekOffset = bytesHashed
    var bytesRemaining = offset - bytesHashed
    let bufferSize = 8 * 1024 * 1024
    while bytesRemaining > 0 {
      let toRead = Int(min(bytesRemaining, Int64(bufferSize)))
      guard let chunk = try await source.read(maxBytes: toRead), !chunk.isEmpty else {
        throw UploadError.localSourceTooSmall(localSize: currentSeekOffset, gcsOffset: offset)
      }
      updateChecksums(data: chunk, startOffset: currentSeekOffset)
      currentSeekOffset += Int64(chunk.count)
      bytesRemaining -= Int64(chunk.count)
    }
    try await source.seek(to: offset)
  }
}
