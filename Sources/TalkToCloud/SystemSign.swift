/*
* Copyright 2020 Coodly LLC
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

#if os(macOS)
import Foundation
import CommonCrypto

public class SystemSign: SignData {
    private lazy var privateKey: SecKey = {
        var importedItems: CFArray?

        let pemData = try! Data(contentsOf: self.pathToPEM)
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

    private let pathToPEM: URL
    public init(pathToPEM: URL) {
        self.pathToPEM = pathToPEM
    }
    
    // Inspired by https://github.com/ooper-shlab/CryptoCompatibility-Swift
    public func sign(_ data: Data) -> String {
        if #available(OSX 10.12, *) {
            return createSignature(of: data)
        } else {
            return transformSign(data)
        }
    }
    
    private func transformSign(_ inputData: Data) -> String {
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
    private func createSignature(of inputData: Data) -> String {
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
#endif
