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

extension Raw {
    internal struct SavedRecord: Codable {
        let recordName: String
        let recordType: String
        let recordChangeTag: String?
        let fields: [String: Raw.Field]

        internal func replacing(fields: [String: Raw.Field]) -> SavedRecord {
            SavedRecord(recordName: recordName, recordType: recordType, recordChangeTag: recordChangeTag, fields: fields)
        }
    }
}

extension Raw.SavedRecord {
    internal init(record: Raw.Record, withChange: Bool = true) {
        self.recordName = record.recordName
        self.recordType = record.recordType
        self.recordChangeTag = withChange ? record.recordChangeTag : nil
        self.fields = record.fields
    }
    
    internal init(delete: Raw.RecordID) {
        recordName = delete.recordName
        recordType = "Forced - does not matter"
        recordChangeTag = "Forced - does not matter"
        fields = [:]
    }
}
