/*
 * Copyright 2016 Coodly LLC
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

public enum CloudResult<T: RemoteRecord> {
    case success([T], (() -> ())?)
    case failure
}

public class CloudContainer {
    private static let baseURL = URL(string: "https://api.apple-cloudkit.com")!

    
    private let container: String
    private let env: Environment
    private let auth: Authenticator
    private let fetch: NetworkFetch
    
    public init(identifier: String, env: Environment, authenticator: Authenticator, fetch: NetworkFetch) {
        container = identifier
        self.env = env
        auth = authenticator
        self.fetch = fetch
    }
    
    public func save<T>(records: [RemoteRecord], in database: CloudDatabase = .public, completion: @escaping ((CloudResult<T>) -> ())) {
        var operations = [[String: AnyObject]]()
        for r in records {
            operations.append(r.toOperation())
        }
        let body: [String: AnyObject] = ["operations": operations as AnyObject]
        send(body: body, to: "/records/modify", in: database, completion: completion)
    }
    
    public func fetch<T>(limit: Int? = nil, desiredKeys: [String]? = nil, filter: Filter? = nil, sort: Sort? = nil, in database: CloudDatabase = .public, completion: @escaping ((CloudResult<T>) -> ())) {
        var query: [String: AnyObject] = ["recordType": T.recordType as AnyObject]
        if let f = filter, let params = f.json() {
            query["filterBy"] = params
        }
        
        if let sort = sort {
            switch sort {
            case .ascending(let key):
                query["sortBy"] = ["fieldName": key, "ascending": true] as AnyObject
            case .descending(let key):
                query["sortBy"] = ["fieldName": key, "ascending": false] as AnyObject
            }
        }
        
        var body: [String: AnyObject] = ["query": query as AnyObject]
        if let limit = limit {
            body["resultsLimit"] = limit as AnyObject
        }
        if let keys = desiredKeys {
            body["desiredKeys"] = keys as AnyObject
        }
        
        send(body: body, to: "/records/query", in: database, completion: completion)
    }
    
    public func fetchFirst<T>(desiredKeys: [String]? = nil, filter: Filter? = nil, sort: Sort? = nil, in database: CloudDatabase = .public, completion: @escaping ((CloudResult<T>) -> ())) {
        fetch(limit: 1, desiredKeys: desiredKeys, filter: filter, sort: sort, in: database, completion: completion)
    }
    
    public func lookup<T>(recordName: String, in database: CloudDatabase = .public, completion: @escaping ((CloudResult<T>) -> Void)) {
        let body: [String: AnyObject] = ["records": [["recordName": recordName]] as AnyObject]
        send(body: body, to: "/records/lookup", in: database, completion: completion)
    }
    
    private func send<T>(body: [String: AnyObject], to path: String, in database: CloudDatabase, completion: @escaping ((CloudResult<T>) -> ())) {
        let fullQueryPath = "/database/1/\(container)/\(env.rawValue)/\(database.rawValue)\(path)"
        let bodyData = try! JSONSerialization.data(withJSONObject: body)
        
        POST(to: fullQueryPath, body: bodyData, completion: completion)
    }
    
    private func POST<T>(to path: String, body data: Data, completion: @escaping ((CloudResult<T>) -> ())) {
        var components = URLComponents(url: CloudContainer.baseURL, resolvingAgainstBaseURL: true)!
        components.path = components.path.appending(path)
        
        let url = components.url!
        
        Logging.log("POST to \(url)")
        
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        
        let additionalHeaders = auth.signedHeaders(for: data, query: path)
        for (name, value) in additionalHeaders {
            request.addValue(value, forHTTPHeaderField: name)
        }
        
        Logging.log("Attach body \(data.count)")
        request.httpBody = data
        
        Logging.log("Headers:")
        request.allHTTPHeaderFields?.forEach() {
            key, value in
            
            Logging.log("\t\(key): \(value)")
        }

        let cursor = Cursor<T>(path: path, data: data, handler: nil, continuation: nil)

        fetch.fetch(request: request as URLRequest) {
            data, response, error in
                        
            self.handleResult(data: data, response: response, error: error, cursor: cursor, completion: completion)
        }
    }
    
    private func continueWith<T>(cursor: Cursor<T>) {
        Logging.log("Continue with \(cursor)")
        let data = cursor.dataWithContinuation()
        POST(to: cursor.path, body: data, completion: cursor.handler!)
    }
    
    private func handleResult<T>(data: Data?, response: URLResponse?, error: Error?, cursor: Cursor<T>, completion: @escaping ((CloudResult<T>) -> ())) {
        guard let responseData = data else {
            Logging.log("No response data")
            return
        }
        
        guard let responseJSON = try! JSONSerialization.jsonObject(with: responseData) as? [String: AnyObject] else {
            Logging.log("Could not get response content")
            return
        }
        
        if let errorCode = responseJSON["serverErrorCode"] as? String, let reason = responseJSON["reason"] {
            Logging.log("\(errorCode) - \(reason)")
            return
        }
        
        guard let records = responseJSON["records"] as? [[String: AnyObject]] else {
            Logging.log("No records in response")
            return
        }
        
        let continuationMarker = responseJSON["continuationMarker"] as? String
        var continuation: (() -> ())? = nil
        if let marker = continuationMarker {
            var used = cursor
            used.continuation = marker
            used.handler = completion
            continuation = {
                self.continueWith(cursor: used)
            }
        }
        
        Logging.log("Parsing \(records.count) records")
        var result = [T]()
        for r in records {
            guard let recordType = r["recordType"] as? String, recordType == T.recordType else {
                continue
            }
            
            var record = T()
            guard record.load(values: r) else {
                continue
            }
            result.append(record)
        }
        
        Logging.log("Loaded \(result.count)")
        
        completion(.success(result, continuation))
    }

}
