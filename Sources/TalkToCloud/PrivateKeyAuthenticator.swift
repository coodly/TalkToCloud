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
import Crypto

public class PrivateKeyAuthenticator: Authenticator {
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
    
    private let apiKeyID: String
    private let sign: SignData
    public init(apiKeyID: String, sign: SignData) {
        self.apiKeyID = apiKeyID
        self.sign = sign
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
        
        let sig = sign.sign(base.data(using: .utf8)!)
        Logging.log("Signature: \(sig)")
        
        return sig
    }

    private func hash(of body: Data) -> String {
        return sha256(data: body)
    }
    
    private func sha256(data : Data) -> String {
        let hashed = SHA256.hash(data: data)
        return Data(hashed).base64EncodedString()
    }
}
