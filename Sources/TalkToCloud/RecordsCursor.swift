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
    internal let deleted: [Raw.Record]
    
    public func records<T: CloudRecord>(of type: T.Type) -> [T] {
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
                fatalError()
            }
        }
        
        return loaded
    }
}
