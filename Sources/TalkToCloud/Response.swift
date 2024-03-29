/*
 * Copyright 2019 Coodly LLC
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

internal struct Response: Decodable {
    let records: [RawRecord]
    let continuationMarker: String?
}

internal struct RawRecord: Decodable {
    let recordName: String
    let recordType: String?
    let fields: [String: FieldValue]?
    let recordChangeTag: String?
    let created: SystemTimestamp?
    let modified: SystemTimestamp?
    let deleted: Bool?
    
    let reason: String?
    let serverErrorCode: String?
    
    var record: Record? {
        guard reason == nil, serverErrorCode == nil else {
            return nil
        }
        
        if deleted ?? false {
            return nil
        }
        
        return Record(recordName: recordName, recordType: recordType!, fields: fields!, recordChangeTag: recordChangeTag!, created: created!, modified: modified!)
    }
    
    var error: RecordError? {
        guard let reason = self.reason, let error = serverErrorCode else {
            return nil
        }
        
        return RecordError(recordName: recordName, reason: reason, serverErrorCode: error)
    }
    
    var deletion: DeletedRecord? {
        guard deleted ?? false else {
            return nil
        }
        
        return DeletedRecord(recordName: recordName)
    }
}

@dynamicMemberLookup
public struct Record {
    public let recordName: String
    public let recordType: String
    internal let fields: [String: FieldValue]
    public let recordChangeTag: String
    public let created: SystemTimestamp
    public let modified: SystemTimestamp
    
    public subscript(dynamicMember member: String) -> String? {
        return fields[member]?.string
    }

    public subscript(dynamicMember member: String) -> [String]? {
        return fields[member]?.stringList
    }

    public subscript(dynamicMember member: String) -> Double? {
        return fields[member]?.double
    }

    public subscript(dynamicMember member: String) -> [Double]? {
        return fields[member]?.doubleList
    }

    public subscript(dynamicMember member: String) -> Int64? {
        return fields[member]?.int64
    }
    
    public subscript(dynamicMember member: String) -> [Int64]? {
        return fields[member]?.int64List
    }

    public subscript(dynamicMember member: String) -> Date? {
        return fields[member]?.date
    }
    
    public subscript(dynamicMember member: String) -> [Date]? {
        return fields[member]?.dates
    }
    
    public subscript(dynamicMember member: String) -> Int? {
        return fields[member]?.int64?.asInt
    }
    
    public subscript(dynamicMember member: String) -> [Int]? {
        return fields[member]?.int64List?.map({ $0.asInt })
    }

    public subscript(dynamicMember member: String) -> Bool {
        return fields[member]?.int64?.asBool ?? false
    }
    
    public subscript(dynamicMember member: String) -> RemoteReference? {
        return fields[member]?.reference
    }
    
    public subscript(dynamicMember member: String) -> [RemoteReference]? {
        return fields[member]?.referenceList
    }

    public subscript(dynamicMember member: String) -> AssetFileDefinition? {
        return fields[member]?.assetDownload
    }
}

public struct SystemTimestamp: Decodable {
    let timestamp: Double
    let userRecordName: String
    let deviceID: String
    
    public var date: Date {
        return timestamp.millisecondsToDate
    }
}

internal struct FieldValue: Decodable {
    enum ValueType: String, Codable {
        case double = "DOUBLE"
        case doubleList = "DOUBLE_LIST"
        case int64 = "INT64"
        case int64List = "INT64_LIST"
        case string = "STRING"
        case stringList = "STRING_LIST"
        case timestamp = "TIMESTAMP"
        case timestampList = "TIMESTAMP_LIST"
        case reference = "REFERENCE"
        case referenceList = "REFERENCE_LIST"
        case assetId = "ASSETID"
        case unknownList = "UNKNOWN_LIST"
    }
    
    enum CodingKeys: String, CodingKey {
        case value
        case type
    }
    
    let type: ValueType
    
    var string: String? = nil
    var stringList: [String]? = nil
    var double: Double? = nil
    var doubleList: [Double]? = nil
    var int64: Int64? = nil
    var int64List: [Int64]? = nil
    var timestamp: Double? = nil
    var timestampList: [Double]? = nil
    var reference: RemoteReference? = nil
    var referenceList: [RemoteReference]? = nil
    var assetDownload: AssetFileDefinition?

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        let type = try values.decode(ValueType.self, forKey: .type)
        self.type = type
        
        switch type {
        case .double:
            double = try? values.decode(Double.self, forKey: .value)
        case .doubleList:
            doubleList = try? values.decode([Double].self, forKey: .value)
        case .int64:
            int64 = try? values.decode(Int64.self, forKey: .value)
        case .int64List:
            int64List = try? values.decode([Int64].self, forKey: .value)
        case .string:
            string = try? values.decode(String.self, forKey: .value)
        case .stringList:
            stringList = try? values.decode([String].self, forKey: .value)
        case .timestamp:
            timestamp = try? values.decode(Double.self, forKey: .value)
        case .timestampList:
            timestampList = try? values.decode([Double].self, forKey: .value)
        case .reference:
            reference = try? values.decode(RemoteReference.self, forKey: .value)
        case .referenceList:
            referenceList = try? values.decode([RemoteReference].self, forKey: .value)
        case .assetId:
            assetDownload = try? values.decode(AssetFileDefinition.self, forKey: .value)
        case .unknownList:
            break
        }
    }
    
    fileprivate var date: Date? {
        return timestamp?.millisecondsToDate
    }

    fileprivate var dates: [Date]? {
        return timestampList?.map({ $0.millisecondsToDate })
    }
}

public struct RecordError {
    public let recordName: String
    public let reason: String
    public let serverErrorCode: String
}

public struct DeletedRecord {
    public let recordName: String
}

internal struct ErrorResponse: Decodable {
    let serverErrorCode: String
    let reason: String
}

internal struct RetryAfterResponse: Decodable {
    let serverErrorCode: String
    let retryAfter: TimeInterval
}

extension Double {
    internal var millisecondsToDate: Date {
        let seconds: TimeInterval = self / 1000.0
        return Date(timeIntervalSince1970: seconds)
    }
}

private extension Int64 {
    var asInt: Int {
        return Int(self)
    }
    
    var asBool: Bool {
        return self != 0
    }
}
