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
    internal struct RecordOrError: Codable {
        let recordName: String
        let recordType: String?
        let recordChangeTag: String?
        let fields: [String: Raw.Field]?
        let created: Raw.Timestamp?
        let modified: Raw.Timestamp?
        let deleted: Bool?
        let reason: String?
        let serverErrorCode: String?
        
        internal var isDeleted: Bool {
            deleted ?? false
        }
    }
}
