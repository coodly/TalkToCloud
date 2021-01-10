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
    internal struct Record: Codable {
        let recordName: String
        let recordType: String
        let recordChangeTag: String
        let fields: [String: Raw.Field]
        let created: Raw.Timestamp
        let modified: Raw.Timestamp
    }
}

extension Raw.Record {
    internal init?(from received: Raw.RecordOrError) {
        guard let recordType = received.recordType,
              let recordChangeTag = received.recordChangeTag,
              let fields = received.fields,
              let created = received.created,
              let modified = received.modified
        else {
            return nil
        }
        
        self.recordName = received.recordName
        self.recordType = recordType
        self.recordChangeTag = recordChangeTag
        self.fields = fields
        self.created = created
        self.modified = modified
    }
}
