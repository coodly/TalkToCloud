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

public enum CloudDatabase: String {
    case `public` = "public"
    case `private` = "private"
    case shared = "shared"
}

public enum Environment: String {
    case development = "development"
    case production = "production"
}

public enum Filter {
    case equals(String, AnyObject)
    case `in`(String, [AnyObject])
    case and([Filter])
    
    func json() -> AnyObject? {
        var method: String?
        var fieldName: String?
        var recordValue: AnyObject?
        switch self {
        case .equals(let key, let value):
            method = "EQUALS"
            fieldName = key
            recordValue = value
        case .in(let key, let values):
            method = "IN"
            fieldName = key
            recordValue = values as AnyObject
        case .and(let filters):
            var combined = [AnyObject]()
            for f in filters {
                if let json = f.json() {
                    combined.append(json)
                }
            }
            
            return combined as AnyObject
        }
        
        guard let comparator = method, let field = fieldName, let record = recordValue else {
            return nil
        }
        
        return ["comparator": comparator, "fieldName": field , "fieldValue": ["value": record]] as AnyObject
    }
    
    private func record(from: Any) -> [String: AnyObject]? {
        var result: [String: Any]?
        if let value = from as? String {
            result = ["String": value]
        }
        
        guard let value = result else {
            return nil
        }
        
        return ["value": value as AnyObject]
    }
}

public enum Sort {
    case ascending(String)
    case descending(String)
}

public protocol CloudRequest {
    func fetchFirst(filter: Filter?, sort: Sort?, in container: String, env: Environment, database: CloudDatabase)
}
