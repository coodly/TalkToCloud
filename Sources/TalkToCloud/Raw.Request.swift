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
        private var zoneID: Raw.ZoneID?
        private var zones: [Raw.Zone]?
        private var operations: [Raw.Operation]?
        private var query: Query?
        private var resultsLimit: Int?
        private var desiredKeys: [String]?
        private var continuationMarker: String?

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

extension Raw.Request {
    internal init(zoneID: Raw.ZoneID, operations: [Raw.Operation]) {
        self.zoneID = zoneID
        zones = nil
        self.operations = operations
        query = nil
        resultsLimit = nil
        desiredKeys = nil
    }
}

extension Raw.Request {
    internal init(zoneID: Raw.ZoneID, query: Raw.Query) {
        self.zoneID = zoneID
        operations = nil
        self.query = query
        self.resultsLimit = nil
        self.desiredKeys = nil
    }
}

extension Raw.Request {
    internal func with(resultsLimit: Int?) -> Raw.Request {
        guard let resultsLimit = resultsLimit else {
            return self
        }

        return Raw.Request(
            zoneID: zoneID,
            operations: operations,
            query: query,
            resultsLimit: resultsLimit,
            desiredKeys: desiredKeys
        )
    }
    
    internal func with(desiredKeys: [String]?) -> Raw.Request {
        guard let desiredKeys = desiredKeys else {
            return self
        }

        return Raw.Request(
            zoneID: zoneID,
            operations: operations,
            query: query,
            resultsLimit: resultsLimit,
            desiredKeys: desiredKeys
        )

    }
    
    internal func with(continuationMarker: String) -> Self {
        var modified = self
        modified.continuationMarker = continuationMarker
        return modified
    }
}
