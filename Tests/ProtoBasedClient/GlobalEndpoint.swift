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

import GoogleCloudSecretmanagerV1
import GoogleCloudWkt
import CryptoSwift

/// Run tests for the global endpoint.
public enum GlobalEndpoint {
  static public func run() async throws {
    let projectId = try projectId()
    let secretId = randomSecretId()
    let client = try SecretManagerService()

    print("Testing createSecret()")
    let create = try await client.createSecret(
      request: CreateSecretRequest(
        parent: "projects/\(projectId)", secretId: secretId,
        secret: Secret(
          replication: Replication(replication: .automatic(Replication.Automatic())),
          labels: ["integration-test": "true"])
      ))
    print("create = \(create)")

    print("\nTesting get_secret()")
    let get = try await client.getSecret(request: GetSecretRequest(name: create.name))
    print("get = \(get)")

    print("\nCreate a secret version to provide a thing to alias")
    let data = "the quick brown fox jumps over the lazy dog".data(using: .utf8)!
    let checksum = CryptoSwift.Checksum.crc32c(data.byteArray)
    let version = try await client.addSecretVersion(
      request: AddSecretVersionRequest(
        parent: get.name,
        payload: SecretPayload(
          data: data,
          dataCrc32C: Int64(checksum),
        )))
    print("version = \(version)")

    print("\nTesting updateSecret()")
    var updatedLabels = get.labels
    updatedLabels["updated"] = "test-1"
    var updatedAnnotations = get.annotations
    updatedAnnotations["updated"] = "test-1"

    let update = try await client.updateSecret(
      request: UpdateSecretRequest(
        secret: Secret(
          name: create.name,
          labels: updatedLabels,
          etag: get.etag,
          versionAliases: ["test-alias": Int64(1)],
          annotations: updatedAnnotations),
        updateMask: GoogleCloudWkt.FieldMask(paths: ["annotations", "labels", "versionAliases"])
      ),
    )
    print("upload = \(update)")

    print("\nTesting listSecrets()")
    let page = try await client.listSecrets(
      request: ListSecretsRequest(parent: "projects/\(projectId)"))
    print("page = \(page)")

    print("\nTesting deleteSecret()")
    try await client.deleteSecret(request: DeleteSecretRequest(name: get.name))
    print("deleteSecret() was successful")
  }
}
