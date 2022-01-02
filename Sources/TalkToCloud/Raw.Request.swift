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
        private var atomic: Bool?
        private var continuationMarker: String?
        private var records: [Raw.Lookup]?

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
    
    internal init(zoneID: Raw.ZoneID, lookup: [Raw.Lookup]) {
        self.zoneID = zoneID
        self.records = lookup
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

        var modified = self
        modified.resultsLimit = resultsLimit
        return modified
    }
    
    internal func with(desiredKeys: [String]?) -> Raw.Request {
        guard let desiredKeys = desiredKeys else {
            return self
        }

        var modified = self
        modified.desiredKeys = desiredKeys
        return modified
    }
    
    internal func with(continuationMarker: String) -> Self {
        var modified = self
        modified.continuationMarker = continuationMarker
        return modified
    }
    
    internal func with(atomic: Bool?) -> Self {
        guard let atomic = atomic else {
            return self
        }
        
        precondition(zoneID != nil && zoneID?.zoneName != Zone.defaultZoneName, "atomic operations not supported in default zone")
        
        var modified = self
        modified.atomic = atomic
        return modified
    }
}
