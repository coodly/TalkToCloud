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

public struct CloudKit {
    public let development: Container
    public let production: Container
    
    public init?(identifier: String, fetch: NetworkFetch) {
        let config = Configuration(containerId: identifier.replacingOccurrences(of: "iCloud.", with: ""))
        
        guard let dev = config.auth(for: .development), let prod = config.auth(for: .production) else {
            Logging.error("No auth")
            return nil
        }
        
        development = Container(
            identifier: identifier,
            env: .development,
            auth: dev,
            fetch: fetch
        )
        production = Container(
            identifier: identifier,
            env: .production,
            auth: prod,
            fetch: fetch
        )
    }
}
