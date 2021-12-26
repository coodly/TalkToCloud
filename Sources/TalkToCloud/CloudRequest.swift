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

//public enum EnumFilter {
//    case equals(String, AnyObject)
//    case notEquals(String, AnyObject)
//    case `in`(String, [AnyObject])
//    case lt(String, AnyObject)
//    case lte(String, AnyObject)
//    case gt(String, AnyObject)
//    case gte(String, AnyObject)
//    case and([EnumFilter])
//
//    func json() -> AnyObject? {
//        var method: String?
//        var fieldName: String?
//        var recordValue: AnyObject?
//        switch self {
//        case .equals(let key, let value):
//            method = "EQUALS"
//            fieldName = key
//            recordValue = decoded(value)
//        case .notEquals(let key, let value):
//            method = "NOT_EQUALS"
//            fieldName = key
//            recordValue = decoded(value)
//        case .in(let key, let values):
//            method = "IN"
//            fieldName = key
//            recordValue = values as AnyObject
//        case .and(let filters):
//            var combined = [AnyObject]()
//            for f in filters {
//                if let json = f.json() {
//                    combined.append(json)
//                }
//            }
//
//            return combined as AnyObject
//        case .lt(let key, let value):
//            method = "LESS_THAN"
//            fieldName = key
//            recordValue = decoded(value)
//        case .lte(let key, let value):
//            method = "LESS_THAN_OR_EQUALS"
//            fieldName = key
//            recordValue = decoded(value)
//        case .gt(let key, let value):
//            method = "GREATER_THAN"
//            fieldName = key
//            recordValue = decoded(value)
//        case .gte(let key, let value):
//            method = "GREATER_THAN_OR_EQUALS"
//            fieldName = key
//            recordValue = decoded(value)
//        }
//
//        guard let comparator = method, let field = fieldName, let record = recordValue else {
//            return nil
//        }
//
//        return ["comparator": comparator, "fieldName": field , "fieldValue": ["value": record]] as AnyObject
//    }
//
//    private func decoded(_ value: AnyObject) -> AnyObject {
//        if let reference = value as? RemoteReference {
//            return reference.dictionary() as AnyObject
//        } else if let date = value as? Date {
//            return date.milliseconds() as AnyObject
//        } else {
//            return value
//        }
//    }
//
//    private func record(from: Any) -> [String: AnyObject]? {
//        var result: [String: Any]?
//        if let value = from as? String {
//            result = ["String": value]
//        }
//
//        guard let value = result else {
//            return nil
//        }
//
//        return ["value": value as AnyObject]
//    }
//}

public protocol CloudRequest {
    func fetchFirst(filter: Filter?, sort: Sort?, in container: String, env: Environment, database: CloudDatabase)
}
