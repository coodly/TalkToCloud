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

public struct Zone {
    private let name: String
    private let database: CloudDatabase
    private let variables: Variables
    internal init(name: String, database: CloudDatabase, variables: Variables) {
        self.name = name
        self.database = database
        self.variables = variables
    }
    
    public func query(recordType: String, limit: Int? = nil, desiredKeys: [String]? = nil, filter: Filter? = nil, sort: Sort? = nil, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
        
        Logging.log("Query: \(recordType)")

        let query = Raw.Query(recordType: recordType)
            .with(sort: sort)
            .with(filter: filter)
        
        let body = Raw.Request(zoneID: Raw.ZoneID(name: name), query: query)
            .with(resultsLimit: limit)
            .with(desiredKeys: desiredKeys)
        
        performRequest(with: body, completion: completion)
    }
    
    public func modify(records: [CloudEncodable], desiredKeys: [String]? = nil, atomic: Bool? = nil, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
        let operations = records.map(Raw.Operation.init(record:))
        let request = Raw.Request(zoneID: Raw.ZoneID(name: name), operations: operations).with(desiredKeys: desiredKeys).with(atomic: atomic)
        let save = ModifyRecordsRequest(body: request, database: database, variables: variables)
        save.perform() {
            result in
            
            switch result {
            case .success(let response):
                let cursor = RecordsCursor(records: response.received, deleted: response.deleted, errors: response.errors, moreComing: false, syncToken: nil, continuation: nil)
                completion(.success(cursor))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func nextPage(with request: Raw.Request, continuation: String, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
        Logging.log("Next page")
        let withContinuation = request.with(continuationMarker: continuation)
        performRequest(with: withContinuation, completion: completion)
    }
    
    private func performRequest(with body: Raw.Request, completion: @escaping ((Result<RecordsCursor, Error>) -> Void)) {
        let request = QueryRecordsRequest(body: body, database: database, variables: variables)
        request.perform() {
            result in
            
            switch result {
            case .success(let response):
                let continuation: (() -> Void)?
                if let token = response.continuationMarker {
                    continuation = {
                        self.nextPage(with: body, continuation: token, completion: completion)
                    }
                } else {
                    continuation = nil
                }
                
                let cursor = RecordsCursor(
                    records: response.received,
                    deleted: [],
                    errors: [],
                    moreComing: response.continuationMarker != nil,
                    syncToken: nil,
                    continuation: continuation
                )
                completion(.success(cursor))
            case .failure(let error):
                completion(.failure(error))
            }
        }

    }
}
