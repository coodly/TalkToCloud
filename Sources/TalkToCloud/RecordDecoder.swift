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

extension String {
    fileprivate static let recordName = "recordName"
    fileprivate static let recordChangeTag = "recordChangeTag"
    fileprivate static let created = "created"
    fileprivate static let modified = "modified"
    
    fileprivate static let system = [recordName, recordChangeTag, created, modified]
}

internal class RecordDecoder: Decoder {
    var codingPath: [CodingKey] = []
    
    var userInfo: [CodingUserInfoKey : Any] = [:]
    
    internal var record: Raw.Record!
    
    func container<Key>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> where Key : CodingKey {
        return KeyedDecodingContainer(KDC(record: record))
    }
    
    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        fatalError()
    }
    
    func singleValueContainer() throws -> SingleValueDecodingContainer {
        fatalError()
    }
    
    struct KDC<Key: CodingKey>: KeyedDecodingContainerProtocol {
        var codingPath: [CodingKey] = []
        
        var allKeys: [Key] = []
        
        private let record: Raw.Record
        init(record: Raw.Record) {
            self.record = record
        }
        
        func contains(_ key: Key) -> Bool {
            if record.fields.keys.contains(key.stringValue) {
                return true
            }
            
            return String.system.contains(key.stringValue)
        }
        
        func decodeNil(forKey key: Key) throws -> Bool {
            if String.system.contains(key.stringValue) {
                return false
            }
            
            return !record.fields.keys.contains(key.stringValue)
        }
        
        func decode(_ type: Bool.Type, forKey key: Key) throws -> Bool {
            if key.stringValue == "deleted" {
                return false
            }
            fatalError(key.stringValue)
        }
        
        func decode(_ type: String.Type, forKey key: Key) throws -> String {
            switch key.stringValue {
            case "recordName":
                return record.recordName
            case "recordChangeTag":
                return record.recordChangeTag
            default:
                break
            }
            
            return try field(for: key).string!
        }
        
        func decode(_ type: Double.Type, forKey key: Key) throws -> Double {
            try field(for: key).double!
        }
        
        func decode(_ type: Float.Type, forKey key: Key) throws -> Float {
            fatalError(key.stringValue)
        }
        
        func decode(_ type: Int.Type, forKey key: Key) throws -> Int {
            fatalError(key.stringValue)
        }
        
        func decode(_ type: Int8.Type, forKey key: Key) throws -> Int8 {
            fatalError(key.stringValue)
        }
        
        func decode(_ type: Int16.Type, forKey key: Key) throws -> Int16 {
            fatalError(key.stringValue)
        }
        
        func decode(_ type: Int32.Type, forKey key: Key) throws -> Int32 {
            fatalError(key.stringValue)
        }
        
        func decode(_ type: Int64.Type, forKey key: Key) throws -> Int64 {
            try field(for: key).int64!
        }
        
        func decode(_ type: UInt.Type, forKey key: Key) throws -> UInt {
            fatalError(key.stringValue)
        }
        
        func decode(_ type: UInt8.Type, forKey key: Key) throws -> UInt8 {
            fatalError(key.stringValue)
        }
        
        func decode(_ type: UInt16.Type, forKey key: Key) throws -> UInt16 {
            fatalError(key.stringValue)
        }
        
        func decode(_ type: UInt32.Type, forKey key: Key) throws -> UInt32 {
            fatalError(key.stringValue)
        }
        
        func decode(_ type: UInt64.Type, forKey key: Key) throws -> UInt64 {
            fatalError(key.stringValue)
        }
        
        func decode<T>(_ type: T.Type, forKey key: Key) throws -> T where T : Decodable {
            if T.self == Date.self, key.stringValue == "createdAt" {
                return record.created.date as! T
            }
            if T.self == Date.self, key.stringValue == "modifiedAt" {
                return record.modified.date as! T
            }
            if key.stringValue == "recordName" {
                return  record.recordName as! T
            }
            if key.stringValue == "recordChangeTag" {
                return  record.recordChangeTag as! T
            }
            if T.self == Date.self {
                return try field(for: key).timestamp!.millisecondsToDate as! T
            }
            if T.self == String.self {
                return try field(for: key).string as! T
            }
            if T.self == Int.self, let value = try field(for: key).int64 {
                return Int(value) as! T
            }
            if T.self == CloudReference.self {
                return try field(for: key).reference as! T
            }
            if T.self == [CloudReference].self {
                return try field(for: key).referenceList as! T
            }
            if T.self == [Int64].self {
                return try field(for: key).int64List as! T
            }
            
            fatalError(key.stringValue)
        }
        
        func nestedContainer<NestedKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> where NestedKey : CodingKey {
            fatalError()
        }
        
        func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
            fatalError(key.stringValue)
        }
        
        func superDecoder() throws -> Decoder {
            fatalError()
        }
        
        func superDecoder(forKey key: Key) throws -> Decoder {
            fatalError(key.stringValue)
        }
        
        private func field(for key: Key) throws -> Raw.Field {
            guard let field = record.fields[key.stringValue] else {
                throw DecodingError.keyNotFound(key, DecodingError.Context(codingPath: codingPath, debugDescription: "TODO"))
            }

            return field
        }
    }
}

