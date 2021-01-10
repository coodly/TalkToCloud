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

let ReservedFields = ["recordName", "recordChangeTag", "proposedName"]

enum OperationType: String, Codable {
    case create = "create"
    case update = "update"
    case delete = "delete"
    case forceDelete = "forceDelete"
}

public protocol RemoteRecord {
    static var recordType: String { get }
    var recordName: String? { get set }
    var proposedName: String? { get set }
    var recordChangeTag: String? { get set }
    
    init()
    mutating func loadFields(from record: Record) -> Bool
}

extension RemoteRecord {
    func toOperation(forced: OperationType? = nil) -> [String: AnyObject] {
        var record: [String: AnyObject] = ["recordType": Self.recordType as AnyObject]
        let operation: OperationType
        if let type = forced, let name = recordName {
            operation = type
            record["recordName"] = name as AnyObject
        } else if let name = recordName {
            operation = .update
            record["recordName"] = name as AnyObject
        } else if let proposed = proposedName {
            operation = .create
            record["recordName"] = proposed as AnyObject
        } else {
            operation = .create
        }
        record["fields"] = fields() as AnyObject
        if let changeTag = recordChangeTag {
            record["recordChangeTag"] = changeTag as AnyObject
        }

        var result: [String: AnyObject] = ["operationType": operation.rawValue as AnyObject]
        result["record"] = record as AnyObject
        return result
    }
    
    func fields() -> [String: AnyObject] {
        if let raw = self as? RawFieldsCopy {
            Logging.log("Using raw fields")
            return raw.rawFields
        }
        
        var result = [String: AnyObject]()
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if ReservedFields.contains(child.label!) {
                continue
            }
            
            guard let label = child.label else {
                continue
            }
            
            if label.starts(with: "_") {
                Logging.verbose("\(label) not serialized for push")
                continue
            }

            if let value = child.value as? String {
                result[label] = ["value": value] as AnyObject
            } else if let value = child.value as? Int {
                result[label] = ["value": value] as AnyObject
            } else if let value = child.value as? Int64 {
                result[label] = ["value": value] as AnyObject
            } else if let value = child.value as? Date {
                result[label] = ["value": value.milliseconds()] as AnyObject
            } else if let value = child.value as? Double {
                result[label] = ["value": value] as AnyObject
            } else if let value = child.value as? Bool {
                result[label] = ["value": value ? 1 : 0] as AnyObject
            } else if let value = child.value as? [String] {
                result[label] = ["value": value] as AnyObject
            } else if let value = child.value as? [Int] {
                result[label] = ["value": value] as AnyObject
            } else if let remote = child.value as? RemoteReference {
                let value = remote.dictionary()
                result[label] = ["value": value] as AnyObject
            } else if let remote = child.value as? [RemoteReference] {
                let value = remote.map({ $0.dictionary() })
                result[label] = ["value": value] as AnyObject
            } else if let asset = child.value as? AssetFileDefinition {
                let value = asset.dictionary()
                result[label] = ["value": value] as AnyObject
            } else {
                Logging.verbose("Could not cast \(child) - \(type(of: child))")
            }
        }
        return result
    }
    
    internal mutating func loadValues(from record: Record) -> Bool {
        recordName = record.recordName
        recordChangeTag = record.recordChangeTag
        
        return loadFields(from: record)
    }
}

extension Date {
    func milliseconds() -> Double {
        let integer = Int(timeIntervalSince1970 * 1000)
        return Double(integer)
    }
}

public extension Dictionary {
    func value(fromField name: String) -> AnyObject? {
        let dict = self as NSDictionary
        guard let valueDict = dict[name] as? [String: AnyObject] else {
            return nil
        }
        
        return valueDict["value"]
    }
    
    func date(fromField name: String) -> Date? {
        guard let milliseconds = value(fromField: name) as? Double else {
            return nil
        }
        
        let seconds: TimeInterval = milliseconds / 1000.0
        
        return Date(timeIntervalSince1970: seconds)
    }
    
    func reference(fromField name: String) -> RemoteReference? {
        guard let value = value(fromField: name) as? [String: String] else {
            return nil
        }
        
        guard let recordName = value["recordName"], let actionString = value["action"], let action = ReferenceAction(rawValue: actionString) else {
            return nil
        }
        
        return RemoteReference(recordName: recordName, action: action)
    }
}
