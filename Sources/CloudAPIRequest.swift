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
import CommonCrypto

@available(*, deprecated: 0, message: "Use CloudContainer")
class CloudAPIRequest<T: RemoteRecord>: NetworkRequest, CloudRequest, APIKeyConsumer {
    public var apiKeyID: String!

    private lazy var dateString: String = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        return formatter.string(from: Date()).appending("Z")
    }()
    
    private var bodyData: Data!
    private var fullQueryPath: String!
    private var env: Environment!
    
    open func performRequest() {
        fatalError("Override \(#function)")
    }

    open override func execute() {
        performRequest()
    }
    
    public func save(record: T, in container: String, env: Environment = .production, database: CloudDatabase = .private) {
        save(records: [record], in: container, env: env, database: database)
    }
    
    public func save(records: [RemoteRecord], in container: String, env: Environment = .production, database: CloudDatabase = .private) {
        var operations = [[String: AnyObject]]()
        for r in records {
            operations.append(r.toOperation())
        }
        let body: [String: AnyObject] = ["operations": operations as AnyObject]
        send(body: body, to: "/records/modify", in: container, env: env, database: database)
    }
    
    public func fetch(limit: Int? = nil, filter: Filter? = nil, sort: Sort? = nil, in container: String, env: Environment = .production, database: CloudDatabase = .private) {
        var query: [String: AnyObject] = ["recordType": T.recordType as AnyObject]
        if let f = filter, let params = f.json() {
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
        
        send(body: body, to: "/records/query", in: container, env: env, database: database)
    }
    
    public func fetchFirst(filter: Filter? = nil, sort: Sort? = nil, in container: String, env: Environment = .production, database: CloudDatabase = .private) {
        fetch(limit: 1, filter: filter, sort: sort, in: container, env: env, database: database)
    }
    
    private func send(body: [String: AnyObject], to path: String, in container: String, env: Environment = .production, database: CloudDatabase) {
        self.env = env
        fullQueryPath = "/database/1/\(container)/\(env.rawValue)/\(database.rawValue)\(path)"
        bodyData = try! JSONSerialization.data(withJSONObject: body)

        Logging.log("\(fullQueryPath)")
        Logging.log(String(data: bodyData, encoding: .utf8))

        POST(to: fullQueryPath, body: bodyData)
    }
    
    open override func handleResult(data: Data?, response: URLResponse?, error: Error?) {
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
        loaded(records: result)
    }
    
    open func loaded(records: [T]) {
        
    }
    
    open override func customHeaders() -> [String : String] {
        return [
            "X-Apple-CloudKit-Request-KeyID": apiKeyID,
            "X-Apple-CloudKit-Request-ISO8601Date": dateString,
            "X-Apple-CloudKit-Request-SignatureV1": calculateSignature()
        ]
    }
    
    private func calculateSignature() -> String {
        let base = "\(dateString):\(bodyHash()):\(fullQueryPath!)"
        
        Logging.log("Base: \(base)")
        
        let sig = signature(of: base)
        Logging.log("Signature: \(sig)")
        
        return sig
    }
    
    // TODO jaanus: not sure if this is extra mad or clever...
    // Do it using proper way in future |-(
    private func signature(of string: String) -> String {
        let fileName = "signed.txt"
        do {
            try FileManager.default.removeItem(atPath: fileName)
        } catch {}
        
        let signedData = string.data(using: String.Encoding.utf8)!
        try! signedData.write(to: URL(fileURLWithPath: fileName))
        
        let task = Process()
        task.launchPath = "/usr/local/bin/openssl"
        task.arguments = ["dgst", "-sha256", "-hex", "-sign", "Config/eckey-\(env.rawValue).pem", fileName]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)!
        let split = output.components(separatedBy: " ")
        let last = split.last!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return last.dataFromHexadecimalString()!.base64EncodedString()
    }
    
    private func bodyHash() -> String {
        Logging.log("Body: \(String(data: bodyData, encoding: String.Encoding.utf8))")
        let sha256Data = sha256(data: bodyData)
        return sha256Data.base64EncodedString()
    }
    
    private func sha256(data : Data) -> Data {
        var hash = [UInt8](repeating: 0,  count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0, CC_LONG(data.count), &hash)
        }
        return Data(bytes: hash)
    }
}

extension NSData {
    func toHexString() -> String {
        
        let string = NSMutableString(capacity: length * 2)
        var byte: UInt8 = 0
        
        for i in 0 ..< length {
            getBytes(&byte, range: NSMakeRange(i, 1))
            string.appendFormat("%02x", byte)
        }
        
        return string as String
    }
}

extension String {
    
    /// Create NSData from hexadecimal string representation
    ///
    /// This takes a hexadecimal representation and creates a NSData object. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// The use of `strtoul` inspired by Martin R at [http://stackoverflow.com/a/26284562/1271826](http://stackoverflow.com/a/26284562/1271826)
    ///
    /// - returns: NSData represented by this hexadecimal string.
    
    func dataFromHexadecimalString() -> NSData? {
        let data = NSMutableData(capacity: characters.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, options: [], range: NSMakeRange(0, characters.count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
            data?.append([num], length: 1)
        }
        
        return data
    }
}

