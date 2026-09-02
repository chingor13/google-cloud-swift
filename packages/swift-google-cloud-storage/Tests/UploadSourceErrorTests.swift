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

@Suite struct UploadSourceErrorTests {
  struct TestError: Error, CustomStringConvertible {
    var description: String { "test error description" }
  }

  @Test func testReadErrorFactoryAndPatternMatching() {
    let underlying = TestError()
    let error = UploadSourceError.readError(underlying)

    guard case .readError(let caught) = error else {
      Issue.record("Expected .readError, got \(error)")
      return
    }
    #expect(caught is TestError)
    #expect(error.description == "readError(test error description)")
  }

  @Test func testUploadErrorWrapsUploadSourceError() {
    let underlying = TestError()
    let sourceError = UploadSourceError.readError(underlying)
    let uploadError = UploadError.uploadSourceError(sourceError)

    guard case .uploadSourceError(let caughtSourceError) = uploadError else {
      Issue.record("Expected .uploadSourceError, got \(uploadError)")
      return
    }
    guard case .readError(let caughtUnderlying) = caughtSourceError else {
      Issue.record("Expected .readError, got \(caughtSourceError)")
      return
    }
    #expect(caughtUnderlying is TestError)
    #expect(
      uploadError.description.contains("uploadSourceError(readError(test error description))"))
  }
}
