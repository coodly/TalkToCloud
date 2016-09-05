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

public class PrivateKeyAuthenticator: Authenticator {
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
    
    private let apiKeyID: String
    private let pathToPEM: String
    
    public init(apiKeyID: String, pathToPEM: String) {
        self.apiKeyID = apiKeyID
        self.pathToPEM = pathToPEM
    }
    
    public func signedHeaders(for data: Data, query: String) -> [String: String] {
        let dateString = curretDateString()
        return [
            "X-Apple-CloudKit-Request-KeyID": apiKeyID,
            "X-Apple-CloudKit-Request-ISO8601Date": dateString,
            "X-Apple-CloudKit-Request-SignatureV1": calculateSignature(dateString: dateString, body: data, fullQueryPath: query)
        ]
    }
    
    private func curretDateString() -> String {
        return dateFormatter.string(from: Date()).appending("Z")
    }
    
    private func calculateSignature(dateString: String, body: Data, fullQueryPath: String) -> String {
        let base = "\(dateString):\(hash(of: body)):\(fullQueryPath)"
        
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
        task.arguments = ["dgst", "-sha256", "-hex", "-sign", pathToPEM, fileName]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: String.Encoding.utf8)!
        let split = output.components(separatedBy: " ")
        let last = split.last!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return last.dataFromHexadecimalString()!.base64EncodedString()
    }
    
    private func hash(of body: Data) -> String {
        let sha256Data = sha256(data: body)
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
