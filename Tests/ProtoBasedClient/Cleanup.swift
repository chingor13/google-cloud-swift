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
import GoogleCloudSecretmanagerV1

func cleanupStaleSecrets() async {
  do {
    try await cleanupStaleSecretsImpl()
  } catch {
    print("Error cleaning up stale secrets: \(error)")
  }
}

func cleanupStaleSecretsImpl() async throws {
  let projectId = try projectId();
  let client = try SecretManagerService()
  let page = try await client.listSecrets(
    request: ListSecretsRequest(parent: "projects/\(projectId)"))

  // Wait at least 48 hours before deleting the resources.
  let slack = UInt64(48 * 3600)
  let deadline = UInt64(Date().timeIntervalSince1970) - slack
  for secret in page.secrets {
    guard let v = secret.labels["integration-test"], v == "true" else {
      continue
    }
    guard let t = secret.createTime, t.seconds < deadline else {
      continue
    }
    try await client.deleteSecret(
      request: DeleteSecretRequest(name: secret.name, etag: secret.etag))
  }
}
