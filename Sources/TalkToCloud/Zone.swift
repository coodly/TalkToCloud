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

extension Zone {
  internal static let defaultZoneName = "_defaultZone"
}

public struct Zone: Sendable {
  internal let name: String
  private let database: CloudDatabase
  private let variables: Variables
  private let performer: RequestPerformer
  internal init(name: String, database: CloudDatabase, variables: Variables) {
    self.name = name
    self.database = database
    self.variables = variables
    self.performer = RequestPerformer(variables: variables, database: database)
  }
    
  public func query(recordType: String, limit: Int? = nil, desiredKeys: [String]? = nil, filter: Filter? = nil, sort: Sort? = nil, syncToken: String? = nil) async throws -> RecordsCursor {
    
    Logging.log("Query: \(recordType)")
    
    let query = Raw.Query(recordType: recordType)
      .with(sort: sort)
      .with(filter: filter)
    
    let body = Raw.Request(zoneID: Raw.ZoneID(name: name), query: query)
      .with(resultsLimit: limit)
      .with(desiredKeys: desiredKeys)
    
    if let syncToken {
      return try await nextPage(with: body, continuation: syncToken)
    } else {
      return try await post(to: "/records/query", body: body)
    }
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
        let cursor = RecordsCursor(records: response.received, deleted: response.deleted, errors: response.errors, moreComing: false, syncToken: nil, nextPage: { nil })
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
        let cursor = RecordsCursor(records: response.received, deleted: response.deleted, errors: response.errors, moreComing: false, syncToken: nil, nextPage: { nil })
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

  public func changes(since token: String?) async throws -> RecordsCursor {
    Logging.log("Fetch changes in \(name) since \(token ?? "nil")")

    var zone = Raw.Zone(zoneID: Raw.ZoneID(name: name))
    zone.syncToken = token

    let body = Raw.Request().query(in: zone, since: token)
    let (data, _) = try await performer.perform(.post, path: "/changes/zone", body: body)
    let response = try performer.decode(Raw.ZoneChangesList.self, from: data)

    guard let zoneChanges = response.changes(in: zone) else {
      Logging.log("No changes in zone \(name)")
      return RecordsCursor(
        records: [],
        deleted: [],
        errors: [],
        moreComing: false,
        syncToken: token,
        nextPage: { nil }
      )
    }

    let nextPage: @Sendable () async throws -> RecordsCursor? = {
      if zoneChanges.moreComing {
        return try await self.changes(since: zoneChanges.syncToken)
      }
      return nil
    }

    return RecordsCursor(
      records: zoneChanges.received,
      deleted: zoneChanges.deleted,
      errors: zoneChanges.errors,
      moreComing: zoneChanges.moreComing,
      syncToken: zoneChanges.syncToken,
      nextPage: nextPage
    )
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
  
  public func upload<Record: CloudDecodable>(asset: AssetUpload, attachedTo: Record) async throws -> RecordsCursor {
    guard let target = try await createAssetRecord(asset: asset) else {
      throw ZoneError.noUploadTargetCreated
    }
    
    let assetDefinition = try await uploadAssetData(asset.data, with: target)
    var rawRecord = Raw.SavedRecord(
      recordName: attachedTo.recordName,
      recordType: Record.recordType,
      recordChangeTag: attachedTo.recordChangeTag,
      fields: [asset.fieldName : Raw.Field(value: assetDefinition)]
    )
    
    let operation = Raw.Operation(record: rawRecord)
    let request = Raw.Request(zoneID: Raw.ZoneID(name: name), operations: [operation])
    
    return try await post(to: "/records/modify", body: request)
  }

  private func createAssetRecord(asset: AssetUpload) async throws -> AssetUploadTarget? {
    let upload = Raw.Request(asset: asset)
    let (data, _) = try await performer.perform(.post, path: "/assets/upload", body: upload)

    struct TokensList: Decodable {
      let tokens: [AssetUploadTarget]
    }

    let list = try performer.decode(TokensList.self, from: data)
    return list.tokens.first
  }
  
  private func uploadAssetData(_ data: Data, with target: AssetUploadTarget) async throws -> AssetFileDefinition {
    struct UploadResponse: Decodable {
      let singleFile: AssetFileDefinition
    }
    
    let response: UploadResponse = try await send(raw: data, to: target.url)
    return response.singleFile
  }

  public func copyRecords(from cursor: RecordsCursor) async throws -> RecordsCursor {
    Logging.verbose("Copy \(cursor.numberOfRecords) records")
    let existing = try await lookup(names: cursor.records.map(\.recordName))
    Logging.verbose("Have \(existing.numberOfRecords) existing")
    var saved: [Raw.SavedRecord] = []
    for record in cursor.records {
      var save = Raw.SavedRecord(record: record)
      save.recordChangeTag = existing.records.first(where: { $0.recordName == record.recordName })?.recordChangeTag
      saved.append(save)
    }
    
    let operations = saved.map(Raw.Operation.init(record:))
    let request = Raw.Request(zoneID: Raw.ZoneID(name: name), operations: operations)

    return try await post(to: "/records/modify", body: request)
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
    
  func post(to path: String, body: Raw.Request) async throws -> RecordsCursor {
    let (data, _) = try await performer.perform(.post, path: path, body: body)
    let response = try performer.decode(Raw.Response.self, from: data)

    let continuation: @Sendable () async throws -> RecordsCursor?
    if let token = response.continuationMarker {
      continuation = {
        try await self.nextPage(with: body, continuation: token)
      }
    } else {
      continuation = { nil }
    }

    return RecordsCursor(
      records: response.received,
      deleted: response.deleted,
      errors: response.errors,
      moreComing: response.continuationMarker != nil,
      syncToken: response.continuationMarker,
      nextPage: continuation
    )
  }
  
  private func send<R: Decodable>(raw data: Data, to url: URL) async throws -> R {
    Logging.log("Send raw data to \(url)")
    let request = NSMutableURLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = data
    request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

    let (responseData, _) = try await variables.fetch.fetch(request as URLRequest)
    if let string = String(data: responseData, encoding: .utf8) {
      Logging.verbose(string)
    }
    return try performer.decode(R.self, from: responseData)
  }
}
