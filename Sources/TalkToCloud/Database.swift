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

public struct Database {
    private let variables: Variables
    private let database: CloudDatabase
    internal init(identifier: String, env: Environment, database: CloudDatabase, auth: Authenticator, fetch: NetworkFetch) {
        self.database = database
        variables = Variables(container: identifier, env: env, auth: auth, fetch: fetch)
    }
    
    public var defaultZone: Zone {
        zone(name: "_defaultZone")
    }
    
    public func zone(name: String) -> Zone {
        Zone(name: name, database: database, variables: variables)
    }
}
