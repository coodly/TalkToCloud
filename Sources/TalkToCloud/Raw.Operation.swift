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
    internal struct Operation: Encodable {
        let operationType: OperationType
        var zone: Raw.Zone?
        var record: Raw.SavedRecord?
        
        static var create: Operation {
            Operation(operationType: .create)
        }

        static var update: Operation {
            Operation(operationType: .update)
        }

        func zone(named: String) -> Operation {
            var modified = self
            
            modified.zone = Raw.Zone(zoneID: Raw.ZoneID(zoneName: named, ownerRecordName: nil, zoneType: nil), syncToken: nil)
            
            return modified
        }
        
        internal func with(record: Raw.SavedRecord) -> Operation {
            var modified = self
            modified.record = record
            return modified
        }
    }
}

extension Raw.Operation {
    internal init(record: Raw.SavedRecord) {
        if record.recordChangeTag != nil {
            self.operationType = .update
        } else {
            self.operationType = .create
        }
            
        self.record = record
    }
    
    internal init(delete: Raw.RecordID) {
        operationType = .forceDelete
        record = Raw.SavedRecord(delete: delete)
    }
}

extension Raw.Operation {
    internal init(record: CloudEncodable) {
        if record.recordChangeTag == nil {
            self.operationType = .create
        } else {
            self.operationType = .update
        }
        
        self.record = Raw.SavedRecord(encoded: record)
    }
}
