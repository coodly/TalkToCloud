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
    internal struct ZoneChanges: Codable {
        let zoneID: Raw.ZoneID
        let moreComing: Bool
        let syncToken: String
        let records: [Raw.RecordOrError]
        
        internal var received: [Raw.Record] {
            records.compactMap({ Raw.Record(from: $0) })
        }

        internal var deleted: [Raw.RecordID] {
            records.filter(\.isDeleted).map({ Raw.RecordID(recordName: $0.recordName) })
        }
        
        internal var errors: [Raw.RecordError] {
            records.compactMap({ Raw.RecordError(from: $0) })
        }
    }
}
