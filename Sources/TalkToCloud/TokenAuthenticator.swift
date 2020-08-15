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

public class TokenAuthenticator: Authenticator {
    private let apiToken: String
    private let tokenStore: WebTokenStore
    
    public var params: [String : String] {
        var result = [String: String]()
        result["ckAPIToken"] = apiToken
        if let token = tokenStore.webToken {
            result["ckWebAuthToken"] = token
        }
        return result
    }
    
    public init(apiToken: String, tokenStore: WebTokenStore) {
        self.apiToken = apiToken
        self.tokenStore = tokenStore
    }
    
    public func signedHeaders(for data: Data, query: String) -> [String: String] {
        [:]
    }
    
    internal func markToken(from response: URLResponse?) {
        guard let httpResponse = response as? HTTPURLResponse, let next = httpResponse.value(forHTTPHeaderField: "X-Apple-CloudKit-Web-Auth-Token") else {
            return
        }

        Logging.verbose("Mark refreshed token")
        tokenStore.webToken = next
    }
}
