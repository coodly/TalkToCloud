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

import Foundation

public class OpenSSLSign {
    private lazy var identifier = UUID().uuidString
    private lazy var signed = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("\(self.identifier)-sign")
    private lazy var writeTo = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("\(self.identifier)-signed")

    private let pathToPEM: URL
    private let autoClean: Bool
    public init(pathToPEM: URL, autoClean: Bool = true) {
        self.pathToPEM = pathToPEM
        self.autoClean = autoClean
    }
    
    deinit {
        guard autoClean else {
            return
        }
        FileManager.default.remove([signed, writeTo])
    }

    public func sign(_ data: Data) -> String {
        FileManager.default.remove([signed, writeTo])
        
        try! data.write(to: signed)
        let result = Shell.shared.openssl.launch(["dgst", "-out", writeTo.path, "-sha256", "-hex", "-sign", pathToPEM.path, signed.path])
        assert(result.status == 0)
        
        let data = try! Data(contentsOf: writeTo)
        let string = String(data: data, encoding: .utf8)!
        let hex = string.components(separatedBy: " ").last!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return hex.dataFromHexadecimalString()!.base64EncodedString()
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
    
    fileprivate func dataFromHexadecimalString() -> NSData? {
        let data = NSMutableData(capacity: count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, options: [], range: NSMakeRange(0, count)) { match, flags, stop in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString.withCString { strtoul($0, nil, 16) })
            data?.append([num], length: 1)
        }
        
        return data
    }
}

