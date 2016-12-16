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
    
    private lazy var privateKey: SecKey = {
        var importedItems: CFArray?

        let pemData = try! Data(contentsOf: URL(fileURLWithPath: self.pathToPEM))
        let err = SecItemImport(
            pemData as CFData,
            "pem" as CFString,
            nil,
            nil,
            [],
            nil,
            nil,
            &importedItems
        )
        assert(err == errSecSuccess)
        
        let importedKeys = importedItems as! [SecKeychainItem]
        assert(importedKeys.count == 1)
        return (importedKeys[0] as AnyObject as! SecKey)
    }()
    
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

    // Inspired by https://github.com/ooper-shlab/CryptoCompatibility-Swift
    private func signature(of string: String) -> String {
        if #available(OSX 10.12, *) {
            return createSignature(of: string)
        } else {
            return transformSign(string)
        }
    }
    
    private func transformSign(_ string: String) -> String {
        let inputData = string.data(using: .utf8)!
        
        var umErrorCF: Unmanaged<CFError>?
        
        guard let transform = SecSignTransformCreate(self.privateKey, &umErrorCF) else {
            fatalError()
        }
        
        let setTypeSuccess = SecTransformSetAttribute(transform, kSecDigestTypeAttribute, kSecDigestSHA2, nil)
        assert(setTypeSuccess)
        
        let setLengthSuccess = SecTransformSetAttribute(transform, kSecDigestLengthAttribute, 256 as CFNumber, nil)
        assert(setLengthSuccess)

        let addSuccess = SecTransformSetAttribute(transform, kSecTransformInputAttributeName, inputData as CFData, &umErrorCF)
        assert(addSuccess)
        
        let resultData = SecTransformExecute(transform, &umErrorCF)
        assert(CFGetTypeID(resultData) == CFDataGetTypeID())
        
        return (resultData as! Data).base64EncodedString()
    }
    
    
    @available(OSX 10.12, *)
    private func createSignature(of string: String) -> String {
        let inputData = string.data(using: .utf8)!
        
        var digest = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
        inputData.withUnsafeBytes {bytes in
            digest.withUnsafeMutableBytes {mutableBytes in
                _ = CC_SHA256(bytes, CC_LONG(inputData.count), mutableBytes)
            }
        }
        
        var umErrorCF: Unmanaged<CFError>? = nil
        let resultData = SecKeyCreateSignature(
            self.privateKey,
            SecKeyAlgorithm.ecdsaSignatureDigestX962SHA256,
            digest as CFData,
            &umErrorCF)
        let data = resultData as! Data
        return data.base64EncodedString()
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
