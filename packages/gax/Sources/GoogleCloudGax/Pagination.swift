// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// For internal use only. This protocol identifies request messages that adhere to the
/// [AIP-158 pagination](https://google.aip.dev/158) standard.
public protocol _PaginatedRequest {
  /// Optional. The maximum number of results to be returned in a single page. If
  /// set to 0, the server decides the number of results to return.
  var pageSize: Int32 { get }

  /// Optional. Pagination token returned in a previous list request.
  var pageToken: String { get set }
}

/// For internal use only. This protocol identifies response messages that adhere to the
/// [AIP-158 pagination](https://google.aip.dev/158) standard.
public protocol _PaginatedResponse<Item> {
  associatedtype Item: Decodable

  var nextPageToken: String { get }

  func _getPaginatedItems() -> [Item]
}

/// A sequence that manages cursor-based pagination automatically.
public final class PaginatedResponseSequence<
  Item: Decodable, RequestType: _PaginatedRequest, ResponseType: _PaginatedResponse<Item>
>:
  AsyncSequence
{
  public typealias Element = Item
  public typealias ListRpc = (RequestType) async throws -> ResponseType

  private let listRpc: ListRpc
  private let baseRequest: RequestType

  // Creates a new paginated response sequence.
  public init(listRpc: @escaping ListRpc, request: RequestType) {
    self.listRpc = listRpc
    self.baseRequest = request
  }

  public func makeAsyncIterator() -> _ItemIterator {
    _ItemIterator(listRpc: listRpc, request: baseRequest)
  }

  public final class _ItemIterator: AsyncIteratorProtocol {
    private let listRpc: ListRpc
    private var buffer: [Item] = []
    private var nextToken: String = String()
    private var hasReachedEnd = false
    private let baseRequest: RequestType

    init(listRpc: @escaping ListRpc, request: RequestType) {
      self.listRpc = listRpc
      self.baseRequest = request
    }

    public func next() async throws -> Item? {
      // 1. If we have cached items, serve them first.
      if !buffer.isEmpty {
        return buffer.removeFirst()
      }

      // 2. Stop if we've previously determined there's no more data.
      guard !hasReachedEnd else { return nil }

      // 3. Fetch the next page. Copy the request and set the pageToken.
      var mutableRequest = baseRequest
      mutableRequest.pageToken = nextToken
      let response = try await listRpc(mutableRequest)
      buffer = response._getPaginatedItems()

      // 4. Update the token. If there is no next token, remember that we
      // don't need to fetch any more pages.
      nextToken = response.nextPageToken
      if nextToken.isEmpty {
        hasReachedEnd = true
      }

      // 5. If the fetch returned nothing, we are done.
      if buffer.isEmpty {
        hasReachedEnd = true
        return nil
      }

      return buffer.removeFirst()
    }
  }
}
