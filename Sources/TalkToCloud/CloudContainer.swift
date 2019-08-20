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

public enum CloudError {
    case undefined
    case noData
    case invalidData
    case server(code: String, reason: String)
    case retry(after: TimeInterval)
    case network(Error)
    case encode(Error)
    case decode(Error)
    case createAsset
    case uploadAsset
}

public struct CloudResult<T: RemoteRecord> {
    public let records: [T]
    public let deleted: [DeletedRecord]
    public let recordErrors: [RecordError]
    public let error: CloudError?
    public let continuation: (() -> Void)?
}

public struct CloudCodedResult<T: Decodable> {
    public let result: T?
    public let error: CloudError?
    public let continuation: (() -> Void)?
}

public class CloudContainer {
    private static let baseURL = URL(string: "https://api.apple-cloudkit.com")!

    private lazy var encoder = JSONEncoder()
    private lazy var decoder = JSONDecoder()
    
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

    public func delete<T>(records: [RemoteRecord], in database: CloudDatabase = .public, completion: @escaping ((CloudResult<T>) -> ())) {
        var operations = [[String: AnyObject]]()
        for r in records {
            operations.append(r.toOperation(forced: .delete))
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
    
    public func lookup<T>(recordName: String, desiredKeys: [String]? = nil, in database: CloudDatabase = .public, completion: @escaping ((CloudResult<T>) -> Void)) {
        lookup(recordNames: [recordName], desiredKeys: desiredKeys, in: database, completion: completion)
    }
    
    public func lookup<T>(recordNames: [String], desiredKeys: [String]? = nil, in database: CloudDatabase = .public, completion: @escaping ((CloudResult<T>) -> Void)) {
        var body: [String: AnyObject] = ["records": recordNames.map({ ["recordName": $0] }) as AnyObject]
        if let keys = desiredKeys {
            body["desiredKeys"] = keys as AnyObject
        }
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
        if let string = String(data: data, encoding: .utf8) {
            Logging.verbose(string)
        }
        
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
        var cloudError: CloudError? = nil
        var result: [T] = []
        var deleted: [DeletedRecord] = []
        var errors: [RecordError] = []
        var continuation: (() -> Void)? = nil
        
        defer {
            Logging.log("Loaded \(result.count)")
            Logging.log("Deleted \(deleted.count)")
            Logging.log("Errors: \(errors.count)")

            completion(CloudResult(records: result, deleted: deleted, recordErrors: errors, error: cloudError, continuation: continuation))
        }
        
        guard let responseData = data else {
            Logging.log("No response data")
            cloudError = .noData
            return
        }
        
        if let string = String(data: responseData, encoding: .utf8) {
            Logging.verbose(string)
        }
        
        if let serverError = try? decoder.decode(ErrorResponse.self, from: responseData) {
            Logging.log("Error response: \(serverError)")
            cloudError = CloudError.server(code: serverError.serverErrorCode, reason: serverError.reason)
            return
        }
        if let retry = try? decoder.decode(RetryAfterResponse.self, from: responseData) {
            Logging.log("Error response: \(retry)")
            cloudError = CloudError.retry(after: retry.retryAfter)
            return
        }

        let response: Response
        do {
            response = try decoder.decode(Response.self, from: responseData)
        } catch {
            cloudError = .decode(error)
            Logging.error("Failed to decode:")
            if let string = String(data: responseData, encoding: .utf8) {
                Logging.error(string)
            }
            return
        }
        
        let records = response.records.filter({ !($0.deleted ?? false) }).compactMap({ $0.record })
        for record in records {
            guard record.recordType == T.recordType else {
                continue
            }
            
            var loaded = T()
            if loaded.loadValues(from: record) {
                result.append(loaded)
            }
        }
        errors = response.records.compactMap({ $0.error })
        deleted = response.records.compactMap({ $0.deletion })
        
        if let marker = response.continuationMarker {
            var used = cursor
            used.continuation = marker
            used.handler = completion
            continuation = {
                self.continueWith(cursor: used)
            }
        }                
    }
}

private extension CloudContainer {
    private func sendCoded<B: Encodable, R: Decodable>(body: B, to path: String, in database: CloudDatabase, completion: @escaping ((CloudCodedResult<R>) -> Void)) {
        let fullQueryPath = "/database/1/\(container)/\(env.rawValue)/\(database.rawValue)\(path)"
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch {
            Logging.error("Encode error: \(error)")
            completion(CloudCodedResult(result: nil, error: CloudError.encode(error), continuation: nil))
            return
        }
        
        var components = URLComponents(url: CloudContainer.baseURL, resolvingAgainstBaseURL: true)!
        components.path = components.path.appending(fullQueryPath)
        
        let url = components.url!
        
        Logging.log("POST to \(url)")
        
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        
        let additionalHeaders = auth.signedHeaders(for: bodyData, query: fullQueryPath)
        for (name, value) in additionalHeaders {
            request.addValue(value, forHTTPHeaderField: name)
        }
        
        Logging.log("Attach body \(bodyData.count)")
        request.httpBody = bodyData
        
        Logging.log("Headers:")
        request.allHTTPHeaderFields?.forEach() {
            key, value in
            
            Logging.log("\t\(key): \(value)")
        }
        
        fetch.fetch(request: request as URLRequest) {
            data, response, error in
            
            self.handleCodedResult(data: data, response: response, error: error, completion: completion)
        }
    }
    
    private func handleCodedResult<R: Decodable>(data: Data?, response: URLResponse?, error: Error?, completion: @escaping ((CloudCodedResult<R>) -> ())) {
        var result: R? = nil
        var cloudError: CloudError? = nil
        
        defer {
            completion(CloudCodedResult(result: result, error: cloudError, continuation: nil))
        }
        
        guard let responseData = data else {
            Logging.log("No response data")
            cloudError = .noData
            return
        }
        
        do {
            result = try decoder.decode(R.self, from: responseData)
        } catch {
            Logging.error("Decode error \(error)")
            cloudError = .decode(error)
        }
    }
}

private extension CloudContainer {
    private func send<R: Decodable>(raw data: Data, to url: URL, completion: @escaping ((CloudCodedResult<R>) -> Void)) {
        Logging.log("Send raw data to \(url)")
        let request = NSMutableURLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        
        fetch.fetch(request: request as URLRequest) {
            data, response, error in
            
            var cloudError: CloudError? = nil
            var result: R? = nil
            var continuation: (() -> Void)? = nil
            
            defer {
                completion(CloudCodedResult(result: result, error: cloudError, continuation: continuation))
            }

            if let error = error {
                Logging.log(error)
                cloudError = .network(error)
                return
            }

            guard let received = data else {
                Logging.log("No response data")
                cloudError = .noData
                return
            }

            do {
                result = try self.decoder.decode(R.self, from: received)
            } catch {
                Logging.error("Response not decoded: \(error)")
                cloudError = .decode(error)
            }
        }
    }
}

extension CloudContainer {
    public func upload<T: RemoteRecord & AssetAttached>(asset: AssetUpload, attachedTo record: T, in database: CloudDatabase = .public, completion: @escaping ((CloudResult<T>) -> ())) {
        Logging.log("Upload asset")
        
        guard let target = createAssetRecord(asset: asset, in: database) else {
            Logging.log("No target created")
            completion(CloudResult(records: [], deleted: [], recordErrors: [], error: CloudError.createAsset, continuation: nil))
            return
        }
        
        Logging.log("Record created")
        
        guard let definition = uploadAssetData(asset.data, with: target) else {
            Logging.log("Binary upload not done")
            completion(CloudResult(records: [], deleted: [], recordErrors: [], error: CloudError.uploadAsset, continuation: nil))
            return
        }
        
        Logging.log("Binary uploaded")
        var updated = record
        updated.attach(definition, fieldName: asset.fieldName)
        
        Logging.log("Save modified record")        
        save(records: [updated], completion: completion)
    }
    
    private func createAssetRecord(asset: AssetUpload, in database: CloudDatabase) -> AssetUploadTarget? {
        let uploadCreate = AssetUploadCreate(asset: asset)
        
        var target: AssetUploadTarget? = nil
        let createHandler: ((CloudCodedResult<AssetCreateResponse>) -> Void) = {
            result in
            
            if let token = result.result?.tokens.first {
                target = token
            } else if let error = result.error {
                Logging.error("Crate asset error: \(error)")
            } else {
                Logging.log("Creating asset record and nothing happened?")
            }
        }
        
        sendCoded(body: uploadCreate, to: "/assets/upload", in: database, completion: createHandler)
        
        return target
    }
    
    private func uploadAssetData(_ data: Data, with target: AssetUploadTarget) -> AssetFileDefinition? {
        var definition: AssetFileDefinition? = nil
        let sendHandler: ((CloudCodedResult<AssetUploadResponse>) -> Void) = {
            result in
            
            if let file = result.result?.singleFile {
                definition = file
            } else if let error = result.error {
                Logging.error("Upload asset data error: \(error)")
            } else {
                Logging.log("Uploaded asset data and nothing happened?")
            }
        }
        send(raw: data, to: target.url, completion: sendHandler)

        return definition
    }
}
