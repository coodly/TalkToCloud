/*
 * Copyright 2016 Coodly LLC
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

public struct RecordsCursor {
    internal let records: [Raw.Record]
    internal let deleted: [Raw.RecordID]
    internal let errors: [Raw.RecordError]
    public let moreComing: Bool
    public let syncToken: String?
    public let continuation: (() -> Void)?

    public func records<T: CloudDecodable>(of type: T.Type) -> [T] {
        Logging.verbose("Decode records named \(T.recordType)")
        let named = records.filter({ $0.recordType == T.recordType })
        Logging.verbose("Have \(named.count) records")
        
        let decoder = RecordDecoder()
        
        var loaded = [T]()
        
        for record in named {
            do {
                decoder.record = record
                let decoded = try T(from: decoder)
                loaded.append(decoded)
            } catch {
                Logging.error(error)
                Logging.log(record.recordName)
                fatalError()
            }
        }
        
        return loaded
    }
    
    public var recordErrors: [RecordError] {
        errors.map(RecordError.init(raw:))
    }
    
    public var deletions: [DeletedRecord] {
        deleted.map(\.recordName).map(DeletedRecord.init(recordName:))
    }
    
    internal var hasRecordsWithAssets: Bool {
        records.map(\.containsAsset).filter({ $0 }).count > 0
    }
    
    public var numberOfRecords: Int {
        records.count
    }
}
