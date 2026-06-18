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

import GoogleCloudLocation
import GoogleCloudSecretmanagerV1
import GoogleCloudTestHelpers
import GoogleCloudWkt
import GoogleIamV1
import CryptoSwift

/// Run tests for the global endpoint.
public enum GlobalEndpoint {
  static public func run() async throws {
    let projectId = try projectId()
    let secretId = randomSecretId()
    let client = try GoogleCloudSecretmanagerV1.Clients.SecretManagerServiceClient()

    print("Testing createSecret()")
    let create = try await client.createSecret(
      request: CreateSecretRequest().with {
        $0.parent = "projects/\(projectId)"
        $0.secretId = secretId
        $0.secret = Secret().with {
          $0.replication = Replication().with {
            $0.replication = .automatic(Replication.Automatic())
          }
          $0.labels = ["integration-test": "true"]
        }
      })
    print("create = \(create)")

    print("\nTesting getSecret()")
    let get = try await client.getSecret(request: GetSecretRequest().with { $0.name = create.name })
    print("get = \(get)")

    try await testSecretVersions(client: client, secretName: create.name)
    try await testIAM(client: client, secretName: create.name)
    try await testLocations(client: client, projectId: projectId)

    print("\nTesting updateSecret()")
    var updatedLabels = get.labels
    updatedLabels["updated"] = "test-1"
    var updatedAnnotations = get.annotations
    updatedAnnotations["updated"] = "test-1"

    let update = try await client.updateSecret(
      request: UpdateSecretRequest().with {
        $0.updateMask = GoogleCloudWkt.FieldMask(paths: ["annotations", "labels", "versionAliases"])
        $0.secret = Secret().with {
          $0.name = create.name
          $0.labels = updatedLabels
          $0.etag = get.etag
          $0.versionAliases = ["test-alias": Int64(1)]
          $0.annotations = updatedAnnotations
        }
      }
    )
    print("update = \(update)")

    print("\nTesting listSecrets()")
    let secrets = try client.listSecrets(
      byItem: ListSecretsRequest().with { $0.parent = "projects/\(projectId)" })
    var count: UInt64 = 0
    for try await secret in secrets {
      print("  secret = \(secret)")
      count += 1
    }
    print("item count = \(count)")

    print("\nTesting deleteSecret()")
    try await client.deleteSecret(request: DeleteSecretRequest().with { $0.name = get.name })
    print("deleteSecret() was successful")
  }

  static private func testSecretVersions(client: SecretManagerService, secretName: String)
    async throws
  {
    print("\nTesting secret version CRUD")
    let data = "the quick brown fox jumps over the lazy dog".data(using: .utf8)!
    let checksum = CryptoSwift.Checksum.crc32c(data.byteArray)
    let version = try await client.addSecretVersion(
      request: AddSecretVersionRequest().with {
        $0.parent = secretName
        $0.payload = SecretPayload().with {
          $0.data = data
          $0.dataCrc32C = Int64(checksum)
        }
      })
    print("version = \(version)")

    print("\nTesting getSecretVersion()")
    let getVersion = try await client.getSecretVersion(
      request: GetSecretVersionRequest().with { $0.name = version.name })
    print("getVersion = \(getVersion)")

    print("\nTesting accessSecretVersion()")
    let accessVersion = try await client.accessSecretVersion(
      request: AccessSecretVersionRequest().with { $0.name = version.name })
    print("accessVersion payload length = \(accessVersion.payload?.data.count ?? 0)")

    print("\nTesting disableSecretVersion()")
    let disabledVersion = try await client.disableSecretVersion(
      request: DisableSecretVersionRequest().with { $0.name = version.name })
    print("disabledVersion state = \(disabledVersion.state)")

    print("\nTesting enableSecretVersion()")
    let enabledVersion = try await client.enableSecretVersion(
      request: EnableSecretVersionRequest().with { $0.name = version.name })
    print("enabledVersion state = \(enabledVersion.state)")

    print("\nTesting listSecretVersions()")
    let versions = try client.listSecretVersions(
      byItem: ListSecretVersionsRequest().with { $0.parent = secretName })
    for try await version in versions {
      print("  version = \(version)")
    }

    print("\nTesting destroySecretVersion()")
    let destroyedVersion = try await client.destroySecretVersion(
      request: DestroySecretVersionRequest().with { $0.name = version.name })
    print("destroyedVersion state = \(destroyedVersion.state)")
  }

  static private func testIAM(client: SecretManagerService, secretName: String) async throws {
    print("\nTesting IAM operations")
    let serviceAccount = try testServiceAccount();
    print("Testing getIamPolicy()")
    var policy = try await client.getIamPolicy(
      request: GetIamPolicyRequest().with { $0.resource = secretName })
    print("policy = \(policy)")

    print("Testing testIamPermissions()")
    let permissions = try await client.testIamPermissions(
      request: TestIamPermissionsRequest().with {
        $0.resource = secretName
        $0.permissions = ["secretmanager.versions.access"]
      })
    print("permissions = \(permissions)")

    print("Testing setIamPolicy()")
    let role = "roles/secretmanager.secretVersionAdder"
    if var found = policy.bindings.first(where: { $0.role == role }) {
      found.members.append("serviceAccount:\(serviceAccount)")
    } else {
      policy.bindings.append(
        Binding().with {
          $0.role = role
          $0.members = ["serviceAccount:\(serviceAccount)"]
        })
    }
    let updatedPolicy = try await client.setIamPolicy(
      request: SetIamPolicyRequest().with {
        $0.resource = secretName
        $0.policy = policy
      })
    print("updatedPolicy = \(updatedPolicy)")
  }

  static private func testLocations(client: SecretManagerService, projectId: String) async throws {
    print("\nTesting location operations")
    print("Testing listLocations()")
    var count: Int64 = 0
    var first: Location? = nil
    let locations = try client.listLocations(
      byItem: ListLocationsRequest().with { $0.name = "projects/\(projectId)" })
    for try await location in locations {
      print("  location = \(location)")
      count += 1
      if first == nil {
        first = location
      }
    }
    print("locations count = \(count)")

    if let firstLocation = first {
      print("Testing getLocation() for \(firstLocation.name)")
      let location = try await client.getLocation(
        request: GetLocationRequest().with { $0.name = firstLocation.name })
      print("location = \(location)")
    }
  }
}
