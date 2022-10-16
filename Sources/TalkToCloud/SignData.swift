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

public struct SignData {
    private let onSign: ((Data) -> String)

    public init(onSign: @escaping ((Data) -> String)) {
        self.onSign = onSign
    }

    public func sign(_ data: Data) -> String {
        onSign(data)
    }
}

extension SignData {
    #if os(macOS)
    public static func system(pathToPEM: URL) -> SignData {
        let sign = SystemSign(pathToPEM: pathToPEM)
        return SignData(
            onSign: { sign.sign($0) }
        )
    }
    #endif
    
    public static func openSSL(pathToPEM: URL) -> SignData {
        let openSSL = OpenSSLSign(pathToPEM: pathToPEM)
        return SignData(
            onSign: { openSSL.sign($0) }
        )
    }
}


