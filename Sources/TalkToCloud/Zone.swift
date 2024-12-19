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

extension Zone {
  internal static let defaultZoneName = "_defaultZone"
}

public struct Zone: Sendable {
  private let decoder = JSONDecoder()
  private let encoder = JSONEncoder()
  
  internal let name: String
  private let database: CloudDatabase
  private let variables: Variables
  internal init(name: String, database: CloudDatabase, variables: Variables) {
    self.name = name
    self.database = database
    self.variables = variables
  }
    
  public func query(recordType: String, limit: Int? = nil, desiredKeys: [String]? = nil, filter: Filter? = nil, sort: Sort? = nil) async throws -> RecordsCursor {
    
    Logging.log("Query: \(recordType)")
    
    let query = Raw.Query(recordType: recordType)
      .with(sort: sort)
      .with(filter: filter)
    
    let body = Raw.Request(zoneID: Raw.ZoneID(name: name), query: query)
      .with(resultsLimit: limit)
      .with(desiredKeys: desiredKeys)

    return try await post(to: "/records/query", body: body)
  }
//  public func query(recordType: String, limit: Int? = nil, desiredKeys: [String]? = nil, filter: Filter? = nil, sort: Sort? = nil, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
//        
//    Logging.log("Query: \(recordType)")
//
//    let query = Raw.Query(recordType: recordType)
//      .with(sort: sort)
//      .with(filter: filter)
//        
//    let body = Raw.Request(zoneID: Raw.ZoneID(name: name), query: query)
//      .with(resultsLimit: limit)
//      .with(desiredKeys: desiredKeys)
//        
//    performRequest(with: body, completion: completion)
//  }

  public func modify(records: [CloudEncodable], desiredKeys: [String]? = nil, atomic: Bool? = nil) async throws -> RecordsCursor {
    let operations = records.map(Raw.Operation.init(record:))
    let request = Raw.Request(zoneID: Raw.ZoneID(name: name), operations: operations).with(desiredKeys: desiredKeys).with(atomic: atomic)
    
    return try await post(to: "/records/modify", body: request)
  }
  
  public func modify(records: [CloudEncodable], desiredKeys: [String]? = nil, atomic: Bool? = nil, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
    let operations = records.map(Raw.Operation.init(record:))
    let request = Raw.Request(zoneID: Raw.ZoneID(name: name), operations: operations).with(desiredKeys: desiredKeys).with(atomic: atomic)
    let save = ModifyRecordsRequest(body: request, database: database, variables: variables)
    save.perform() {
      result in
            
      switch result {
      case .success(let response):
        let cursor = RecordsCursor(records: response.received, deleted: response.deleted, errors: response.errors, moreComing: false, syncToken: nil, nextPage: { nil })
        completion(.success(cursor))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }
    
  public func delete(records: [CloudEncodable], atomic: Bool? = nil, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
    delete(names: records.map(\.recordName), atomic: atomic, completion: completion)
  }

  public func delete(names: [String], atomic: Bool? = nil) async throws -> RecordsCursor {
    let operations = names.map(Raw.Operation.init(deleteName:))
    let request = Raw.Request(zoneID: Raw.ZoneID(name: name), operations: operations).with(atomic: atomic)
    
    return try await post(to: "/records/modify", body: request)
  }
  
  public func delete(names: [String], atomic: Bool? = nil, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
    let operations = names.map(Raw.Operation.init(deleteName:))
    let request = Raw.Request(zoneID: Raw.ZoneID(name: name), operations: operations).with(atomic: atomic)
    let save = ModifyRecordsRequest(body: request, database: database, variables: variables)
    save.perform() {
      result in
            
      switch result {
      case .success(let response):
        let cursor = RecordsCursor(records: response.received, deleted: response.deleted, errors: response.errors, moreComing: false, syncToken: nil, nextPage: { nil })
        completion(.success(cursor))
      case .failure(let error):
        completion(.failure(error))
      }
    }
  }

  public func lookup(names: [String], desiredKeys: [String]? = nil) async throws -> RecordsCursor {
    let lookup = names.map({ Raw.Lookup(recordName: $0) })
    let body = Raw.Request(zoneID: Raw.ZoneID(name: name), lookup: lookup).with(desiredKeys: desiredKeys)
    return try await post(to: "/records/lookup", body: body)
  }
  
  //public func lookup(names: [String], desiredKeys: [String]? = nil, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
  //  let lookup = names.map({ Raw.Lookup(recordName: $0) })
  //  let body = Raw.Request(zoneID: Raw.ZoneID(name: name), lookup: lookup).with(desiredKeys: desiredKeys)
  //  let request = LookupRequest(body: body, database: database, variables: variables)
  //  request.perform() {
  //    result in
  //
  //    switch result {
  //    case .success(let response):
  //      let cursor = RecordsCursor(
  //        records: response.received,
  //        deleted: response.deleted,
  //        errors: response.errors,
  //        moreComing: false,
  //        syncToken: nil,
  //        continuation: nil
  //      )
  //      completion(.success(cursor))
  //    case .failure(let error):
  //      completion(.failure(error))
  //    }
  //  }
  //}
    
  private func nextPage(with request: Raw.Request, continuation: String) async throws -> RecordsCursor {
    Logging.log("Next page")
    let withContinuation = request.with(continuationMarker: continuation)
    return try await post(to: "/records/query", body: withContinuation)
  }
    
  private func performRequest(with body: Raw.Request, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
    fatalError()
    //let request = QueryRecordsRequest(body: body, database: database, variables: variables)
    //request.perform() {
    //  result in
    //
    //  switch result {
    //  case .success(let response):
    //    let continuation: (() -> Void)?
    //    if let token = response.continuationMarker {
    //      continuation = {
    //        self.nextPage(with: body, continuation: token, completion: completion)
    //      }
    //    } else {
    //      continuation = nil
    //    }
    //
    //    let cursor = RecordsCursor(
    //      records: response.received,
    //      deleted: [],
    //      errors: [],
    //      moreComing: response.continuationMarker != nil,
    //      syncToken: nil,
    //      continuation: continuation
    //    )
    //    completion(.success(cursor))
    //  case .failure(let error):
    //    completion(.failure(error))
    //  }
    //}
  }
  
  func get(path: String, parameters: [String: String]) async throws -> RecordsCursor {
    try await perform(.get, path: path, parameters: parameters)
  }
  
  func post(to path: String, body: Raw.Request, parameters: [String: String] = [:]) async throws -> RecordsCursor {
    try await perform(.post, path: path, body: body, parameters: parameters)
  }
  
  private enum Method: String {
    case post = "POST"
    case get = "GET"
  }
  
  private func perform(_ method: Method, path: String, body: Raw.Request? = nil, parameters: [String: String]) async throws -> RecordsCursor {
    let baseURL = URL(string: "https://api.apple-cloudkit.com/database/1/")!
    let fullQueryPath = "\(variables.container)/\(variables.env.rawValue)/\(database.rawValue)\(path)"
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true)!
    components.path = components.path.appending(fullQueryPath)
    
    var url = components.url!
    
    for (name, value) in variables.auth.params {
      url = url.appending(param: name, value: value)
    }

    Logging.log("\(method.rawValue) to \(url.absoluteString)")
    
    let request = NSMutableURLRequest(url: url)
    request.httpMethod = method.rawValue
    
    request.addValue("application/json", forHTTPHeaderField: "Content-Type")
    
    if let body {
      do {
        let data = try encoder.encode(body)
        request.httpBody = data
    
        let additionalHeaders = variables.auth.signedHeaders(for: data, query: url.path)
        for (name, value) in additionalHeaders {
          request.addValue(value, forHTTPHeaderField: name)
        }
    
        if let string = String(data: data, encoding: .utf8) {
          Logging.verbose("Body:")
          Logging.verbose(string)
        }
      } catch {
        Logging.error("Encode body error: \(error)")
        fatalError()
      }
    }
    
    
    let (data, response) = try await variables.fetch.fetch(request as URLRequest)

    if let token = variables.auth as? TokenAuthenticator {
      token.markToken(from: response)
    }
        
    if let string = String(data: data, encoding: .utf8) {
      Logging.verbose(string)
    }
        
    let result: Result<Raw.Response, any Error> = decodeValue(from: data)
    switch result {
    case .success(let response):
      let continuation: @Sendable () async throws -> RecordsCursor?
      if let token = response.continuationMarker {
        continuation = {
          try await self.nextPage(with: body!, continuation: token)
        }
      } else {
        continuation = { nil }
      }
              
      let cursor = RecordsCursor(
        records: response.received,
        deleted: [],
        errors: [],
        moreComing: response.continuationMarker != nil,
        syncToken: nil,
        nextPage: continuation
      )
      return cursor
    case .failure(let error):
      throw error
    }
  }
    
  private func decodeValue<T: Decodable>(from data: Data) -> Result<T, Error> {
    do {
      let value = try decoder.decode(T.self, from: data)
      return .success(value)
    } catch {
      Logging.error("Decode error: \(error)")
      return .failure(decodeError(from: data, fallback: error))
    }
  }
    
  private func decodeError(from data: Data, fallback: Error) -> Error {
    if let error = try? decoder.decode(Raw.Error.self, from: data) {
      return error.presented
    } else {
      return fallback
    }
  }
}
