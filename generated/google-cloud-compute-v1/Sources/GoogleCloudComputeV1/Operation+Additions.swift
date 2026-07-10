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

#if Addresses || Autoscalers || BackendBuckets || BackendServices || CrossSiteNetworks || Disks || ExternalVpnGateways || FirewallPolicies || Firewalls || ForwardingRules || FutureReservations || GlobalAddresses || GlobalForwardingRules || GlobalNetworkEndpointGroups || GlobalOperations || GlobalOrganizationOperations || GlobalPublicDelegatedPrefixes || GlobalVmExtensionPolicies || HealthChecks || HttpHealthChecks || HttpsHealthChecks || Images || InstanceGroupManagerResizeRequests || InstanceGroupManagers || InstanceGroups || InstanceSettings || InstanceTemplates || Instances || InstantSnapshotGroups || InstantSnapshots || InterconnectAttachmentGroups || InterconnectAttachments || InterconnectGroups || Interconnects || Licenses || MachineImages || NetworkAttachments || NetworkEdgeSecurityServices || NetworkEndpointGroups || NetworkFirewallPolicies || Networks || NodeGroups || NodeTemplates || OrganizationSecurityPolicies || PacketMirrorings || PreviewFeatures || Projects || PublicAdvertisedPrefixes || PublicDelegatedPrefixes || RegionAutoscalers || RegionBackendBuckets || RegionBackendServices || RegionCommitments || RegionCompositeHealthChecks || RegionDisks || RegionHealthAggregationPolicies || RegionHealthCheckServices || RegionHealthChecks || RegionHealthSources || RegionInstanceGroupManagerResizeRequests || RegionInstanceGroupManagers || RegionInstanceGroups || RegionInstanceTemplates || RegionInstances || RegionInstantSnapshotGroups || RegionInstantSnapshots || RegionNetworkEndpointGroups || RegionNetworkFirewallPolicies || RegionNotificationEndpoints || RegionOperations || RegionSecurityPolicies || RegionSnapshotSettings || RegionSnapshots || RegionSslCertificates || RegionSslPolicies || RegionTargetHttpProxies || RegionTargetHttpsProxies || RegionTargetTcpProxies || RegionUrlMaps || ReservationBlocks || ReservationSlots || ReservationSubBlocks || Reservations || ResourcePolicies || RolloutPlans || Rollouts || Routers || Routes || SecurityPolicies || ServiceAttachments || SnapshotSettings || Snapshots || SslCertificates || SslPolicies || StoragePools || Subnetworks || TargetGrpcProxies || TargetHttpProxies || TargetHttpsProxies || TargetInstances || TargetPools || TargetSslProxies || TargetTcpProxies || TargetVpnGateways || UrlMaps || VpnGateways || VpnTunnels || WireGroups || ZoneOperations || ZoneVmExtensionPolicies

  import GoogleCloudGax
  import GoogleCloudWkt
  import GoogleRpc

  extension Operation {
    func _done() -> Swift.Bool {
      if let s = self.status, s == .done {
        return true
      }
      return false
    }

    func _name() -> Swift.String {
      return self.name ?? ""
    }

    func _detectErrors() throws {
      if self.error != nil || (self.httpErrorStatusCode ?? 0) != 0 || self.httpErrorMessage != nil {
        throw GoogleCloudGax.RequestError.service(
          GoogleCloudGax.ServiceError(
            code: GoogleRpc.Code(intValue: Int(self.httpErrorStatusCode ?? 0)),
            message: self.httpErrorMessage ?? "Operation failed",
            details: self.error?.errors.compactMap { try? GoogleCloudWkt.Any(fromMessage: $0) }.map
            {
              .other($0)
            } ?? []
          )
        )
      }

      if let metadata = self.instancesBulkInsertOperationMetadata,
        metadata.perLocationStatus.values.contains(where: { ($0.failedToCreateVmCount ?? 0) > 0 })
      {
        throw GoogleCloudGax.RequestError.service(
          GoogleCloudGax.ServiceError(
            code: .unknown,
            message: "Instances bulk insert operation failed",
            details: [.other(try! GoogleCloudWkt.Any(fromMessage: metadata))]
          )
        )
      }

      if let metadata = self.setCommonInstanceMetadataOperationMetadata,
        metadata.perLocationOperations.values.contains(where: { $0.error != nil })
      {
        throw GoogleCloudGax.RequestError.service(
          GoogleCloudGax.ServiceError(
            code: .unknown,
            message: "Set common instance metadata operation failed",
            details: [.other(try! GoogleCloudWkt.Any(fromMessage: metadata))]
          )
        )
      }
    }
  }

#endif
