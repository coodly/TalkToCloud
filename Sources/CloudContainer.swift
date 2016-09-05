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
    
    public func save<T: RemoteRecord>(records: [RemoteRecord], in database: CloudDatabase = .public, completion: (([T]) -> ())) {
        var operations = [[String: AnyObject]]()
        for r in records {
            operations.append(r.toOperation())
        }
        let body: [String: AnyObject] = ["operations": operations as AnyObject]
        send(body: body, to: "/records/modify", in: database, completion: completion)
    }
    
    public func fetch<T: RemoteRecord>(limit: Int? = nil, filter: Filter? = nil, sort: Sort? = nil, in database: CloudDatabase = .public, completion: (([T]) -> ())) {
        var query: [String: AnyObject] = ["recordType": T.recordType as AnyObject]
        if let f = filter, let params = f.dictionary() {
            query["filterBy"] = params as AnyObject
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
        
        send(body: body, to: "/records/query", in: database, completion: completion)
    }
    
    public func fetchFirst<T: RemoteRecord>(filter: Filter? = nil, sort: Sort? = nil, in database: CloudDatabase = .public, completion: (([T]) -> ())) {
        fetch(limit: 1, filter: filter, sort: sort, in: database, completion: completion)
    }
    
    private func send<T: RemoteRecord>(body: [String: AnyObject], to path: String, in database: CloudDatabase, completion: (([T]) -> ())) {
        let fullQueryPath = "/database/1/\(container)/\(env.rawValue)/\(database.rawValue)\(path)"
        let bodyData = try! JSONSerialization.data(withJSONObject: body)
        
        POST(to: fullQueryPath, body: bodyData, completion: completion)
    }
    
    public func POST<T: RemoteRecord>(to path: String, body data: Data, completion: (([T]) -> ())) {
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
        
        Logging.log("Headers: \(request.allHTTPHeaderFields)")
        
        fetch.fetch(request: request as URLRequest) {
            data, response, error in
            
            if let data = data, let string = String(data: data, encoding: .utf8) {
                Logging.log(string)
            }
            
            self.handleResult(data: data, response: response, error: error, completion: completion)
        }
    }
    
    private func handleResult<T: RemoteRecord>(data: Data?, response: URLResponse?, error: Error?, completion: (([T]) -> ())) {
        guard let responseData = data else {
            Logging.log("No response data")
            return
        }
        
        guard let responseJSON = try! JSONSerialization.jsonObject(with: responseData) as? [String: AnyObject] else {
            Logging.log("Could not get response content")
            return
        }
        
        guard let records = responseJSON["records"] as? [[String: AnyObject]] else {
            Logging.log("No records in response")
            return
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
        completion(result)
    }

}
