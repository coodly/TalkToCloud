/*
 * Copyright 2021 Coodly LLC
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

public struct Authentication {
    private let onParams: (() -> [String: String])
    private let onSignHeaders: ((Data, String) -> [String: String])
    private let onMarkToken: ((URLResponse?) -> Void)
    
    public init(
        onParams: @escaping (() -> [String: String]),
        onSignHeaders: @escaping ((Data, String) -> [String: String]),
        onMarkToken: @escaping ((URLResponse?) -> Void)
    ) {
        self.onParams = onParams
        self.onSignHeaders = onSignHeaders
        self.onMarkToken = onMarkToken
    }
    
    internal func params() -> [String: String] {
        onParams()
    }
    
    internal func signedHeaders(for data: Data, query: String) -> [String: String] {
        onSignHeaders(data, query)
    }
    
    internal func markToken(from response: URLResponse?) {
        onMarkToken(response)
    }
}

extension Authentication {
    public static func tokenAuth(with token: String, store: WebTokenStore) -> Authentication {
        let tokenAuth = TokenAuthenticator(apiToken: token, tokenStore: store)
        return Authentication(
            onParams: { tokenAuth.params },
            onSignHeaders: { tokenAuth.signedHeaders(for: $0, query: $1)},
            onMarkToken: { tokenAuth.markToken(from: $0) }
        )
    }
    
    public static func privateKeyAuth(with key: String, sign: SignData) -> Authentication {
        let keyAuthentication = PrivateKeyAuthenticator(apiKeyID: key, sign: sign)
        return Authentication(
            onParams: { keyAuthentication.params },
            onSignHeaders: { keyAuthentication.signedHeaders(for: $0, query: $1) },
            onMarkToken: { _ in }
        )
    }
}
