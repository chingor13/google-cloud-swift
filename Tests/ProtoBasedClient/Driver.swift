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
import GoogleCloudGax

// All the code is compiled by default. The driver to run the code is only enabled when the
// `IntegrationTests` package trait is enabled.
#if IntegrationTests
  @Suite struct ProtoBasedClient {
    @Test func globalEndpoint() async throws {
      await cleanupStaleSecrets()
      do {
        try await GlobalEndpoint.run()
      } catch let error as GoogleCloudGax.RequestError {
        if case let .http(details) = error {
          let p = String(data: details.payload, encoding: .utf8)!
          print("### payload=\(p) error=\(error)")
        } else {
          print("### error=\(error)")
        }
        throw error
      } catch {
        print("### error=\(error)")
        throw error
      }
    }
  }
#endif
