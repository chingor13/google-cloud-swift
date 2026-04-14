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

/// Represents an error while trying to make a request to Google Cloud.
///
/// Requests to Google Cloud may fail for a number of reasons: the application may have configured
/// an invalid endpoint, the network may experience a temporary problem, there may be problems
/// trying to create the authentication tokens, or the service may reject the request, to name just
/// a few.
public enum RequestError: Error {
  /// Cannot construct the URL path to send the request.
  ///
  /// ## Troubleshooting
  ///
  /// The most common cause for this error is to leave some critical field or fields in the request
  /// uninitialized or initialized to a value that produces invalid URL.
  ///
  /// Review the fields in your request object, which field is causing the problem varies by service
  /// and request, but the most common are `parent`, and `name`.
  case binding(String)

  /// The HTTP transport returned an unexpected response type.
  ///
  /// ## Troubleshooting
  ///
  /// The client libraries expect ``HTTPURLResponse`` as responses from the ``URLSession`` calls. The most common cause
  /// for this error is using an `ftp`, or `file` endpoint that just happens to work.
  case badResponseType

  /// The HTTP transport failed before getting a full error from the service.
  ///
  /// ## Troubleshooting
  ///
  /// This indicates that an HTTP request returned a error status code, but the payload was not a valid service error.
  /// Google Cloud services are behind load balancers and/or proxy servers. These may return HTTP errors before the
  /// request makes it to the Google Cloud service.
  ///
  /// Review your network settings and the request fields. Also examine the response, sometimes it contains information
  /// in human readable form.
  case http(HTTPDetails)

  /// The service returned a well-formed error response.
  ///
  /// ## Troubleshooting
  ///
  /// Check the error type, error message, and error details. Then consult the documentation for the service.
  case service(ServiceDetails)
}

/// The details for ``RequestError/http(_:)``.
public struct HTTPDetails: Sendable {
  /// The HTTP status code.
  public let http_status_code: Int

  /// The HTTP headers.
  public let headers: [String: String]

  /// The contents of the HTTP error response.
  public let payload: Data

  /// Create a a new `HTTPDetails`.
  public init(
    http_status_code: Int,
    headers: [String: String],
    payload: Data = Data()
  ) {
    self.http_status_code = http_status_code
    self.headers = headers
    self.payload = payload
  }
}

/// The details for ``RequestError/service(_:)``.
public struct ServiceDetails: Sendable {
  /// The status code.
  public let code: Int
  /// The error message.
  public let message: String

  /// Create a a new `ServiceDetails`.
  public init(
    code: Int,
    message: String,
  ) {
    self.code = code
    self.message = message
  }
}
