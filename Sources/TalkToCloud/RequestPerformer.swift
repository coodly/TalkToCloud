/*
 * Copyright 2021 Coodly LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import Foundation
#if canImport(FoundationNetworking)
  import FoundationNetworking
#endif

internal struct RequestPerformer: Sendable {
  internal enum Method: String, Sendable {
    case post = "POST"
    case get = "GET"
  }

  private static let baseURL = URL(string: "https://api.apple-cloudkit.com/database/1/")!

  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  private let variables: Variables
  private let database: CloudDatabase

  internal init(variables: Variables, database: CloudDatabase) {
    self.variables = variables
    self.database = database
  }

  internal func perform(_ method: Method, path: String, body: Raw.Request? = nil) async throws -> (Data, URLResponse) {
    let fullQueryPath = "\(variables.container)/\(variables.env.rawValue)/\(database.rawValue)\(path)"
    var components = URLComponents(url: RequestPerformer.baseURL, resolvingAgainstBaseURL: true)!
    components.path = components.path.appending(fullQueryPath)

    var url = components.url!

    for (name, value) in variables.auth.params {
      url = url.appending(param: name, value: value)
    }

    Logging.log("\(method.rawValue) to \(url.absoluteString)")

    let request = NSMutableURLRequest(url: url)
    request.httpMethod = method.rawValue
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")

    let bodyData: Data
    if let body {
      do {
        bodyData = try encoder.encode(body)
        request.httpBody = bodyData

        if let string = String(data: bodyData, encoding: .utf8) {
          Logging.verbose("Body:")
          Logging.verbose(string)
        }
      } catch {
        Logging.error("Encode body error: \(error)")
        throw error
      }
    } else {
      bodyData = Data()
    }

    let additionalHeaders = variables.auth.signedHeaders(for: bodyData, query: url.path)
    for (name, value) in additionalHeaders {
      request.addValue(value, forHTTPHeaderField: name)
    }

    let (data, response) = try await variables.fetch.fetch(request as URLRequest)

    if let token = variables.auth as? TokenAuthenticator {
      token.markToken(from: response)
    }

    if let string = String(data: data, encoding: .utf8) {
      Logging.verbose(string)
    }

    return (data, response)
  }

  internal func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    do {
      return try decoder.decode(type, from: data)
    } catch {
      Logging.error("Decode error: \(error)")
      Logging.error(String(data: data, encoding: .utf8) ?? "")
      if let cloudError = try? decoder.decode(Raw.Error.self, from: data) {
        throw cloudError.presented
      }
      throw error
    }
  }
}
