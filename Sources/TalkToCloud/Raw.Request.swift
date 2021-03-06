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

extension Raw {
    internal struct Request: Encodable {
        private var zones: [Raw.Zone]?
        private var operations: [Raw.Operation]?
        
        internal func query(in zones: [Raw.Zone]) -> Raw.Request {
            var modified = self
            modified.zones = zones
            return modified
        }
        
        internal func query(in zone: Raw.Zone, since token: String?) -> Raw.Request {
            var withToken = zone
            withToken.syncToken = token
            
            var modified = self
            modified.zones = [withToken]
            return modified
        }
        
        internal func modify(operation: Operation) -> Request {
            var modified = self
            
            modified.operations = [operation]
            
            return modified
        }
    }
}
