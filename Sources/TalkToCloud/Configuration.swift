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

public struct Configuration {
    private let identifier: String
    public init(containerId: String) {
        identifier = containerId
    }
    
    public func productionContainer(with fetch: NetworkFetch) -> CloudContainer {
        return container(for: .production, using: fetch)
    }

    public func developmentContainer(with fetch: NetworkFetch) -> CloudContainer {
        return container(for: .development, using: fetch)
    }

    private func container(for env: Environment, using fetch: NetworkFetch) -> CloudContainer {
        let auth = auth(for: env)
        return CloudContainer(identifier: "iCloud.\(identifier)", env: env, authenticator: auth, fetch: fetch)
    }
    
    internal func auth(for env: Environment) -> PrivateKeyAuthenticator {
        let keyID = key(for: env)
        let pem = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Config", isDirectory: true).appendingPathComponent("\(identifier)-\(env.rawValue).pem")
        #if os(macOS)
        let sign = SignData.system(pathToPEM: pem)
        #else
        let sign = SignData.openSSL(pathToPEM: pem)
        #endif
        return PrivateKeyAuthenticator(apiKeyID: keyID, sign: sign)
    }
    
    private func key(for env: Environment) -> String {
        let devData = try! Data(contentsOf: URL(fileURLWithPath: "Config/\(identifier)-\(env.rawValue).key"))
        return String(data: devData, encoding: .utf8)!.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
