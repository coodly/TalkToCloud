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
    internal struct Field: Codable {
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
        var reference: CloudReference? = nil
        var referenceList: [CloudReference]? = nil
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
                reference = try? values.decode(CloudReference.self, forKey: .value)
            case .referenceList:
                referenceList = try? values.decode([CloudReference].self, forKey: .value)
            case .assetId:
                assetDownload = try? values.decode(AssetFileDefinition.self, forKey: .value)
            case .unknownList:
                stringList = []
                doubleList = []
                int64List = []
                timestampList = []
                referenceList = []
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type.rawValue, forKey: .type)
            
            switch type {
            case .double:
                try container.encode(double, forKey: .value)
            case .doubleList:
                try container.encode(doubleList, forKey: .value)
            case .int64:
                try container.encode(int64, forKey: .value)
            case .int64List:
                try container.encode(int64List, forKey: .value)
            case .string:
                try container.encode(string, forKey: .value)
            case .stringList:
                try container.encode(stringList, forKey: .value)
            case .timestamp:
                try container.encode(timestamp, forKey: .value)
            case .timestampList:
                try container.encode(timestampList, forKey: .value)
            case .reference:
                try container.encode(reference, forKey: .value)
            case .referenceList:
                try container.encode(referenceList, forKey: .value)
            case .assetId where assetDownload?.receipt != nil:
                try container.encode(assetDownload, forKey: .value)
            case .assetId:
                break
            case .unknownList:
                try container.encode(referenceList, forKey: .value)
            }
        }
    }
}

extension Raw.Field {
    internal init(value: Encodable) {
        if let value = value as? String {
            self.type = .string
            self.string = value
        } else if let value = value as? [String] {
            self.type = .stringList
            self.stringList = value
        } else if let value = value as? Double {
            self.type = .double
            self.double = value
        } else if let value = value as? [Double] {
            self.type = .doubleList
            self.doubleList = value
        } else if let value = value as? Int64 {
            self.type = .int64
            self.int64 = value
        } else if let value = value as? [Int64] {
            self.type = .int64List
            self.int64List = value
        } else if let value = value as? Date {
            self.type = .timestamp
            self.timestamp = value.milliseconds()
        } else if let value = value as? [Date] {
            self.type = .timestampList
            self.timestampList = value.map({ $0.milliseconds() })
        } else {
            fatalError()
        }
    }
}

extension Raw.Field {
    internal static func encodeFields(in record: CloudEncodable) -> [String: Raw.Field] {
        var fields = [String: Raw.Field]()
        let mirror = Mirror(reflecting: record)
        let systemFields = ["recordType", "recordName", "recordChangeTag"]
        for (label, value) in mirror.children {
            guard case Optional<Any>.some(_) = value else {
                continue
            }
            
            guard let label = label, let value = value as? Encodable else {
                continue
            }
            
            if systemFields.contains(label) {
                continue
            }
            
            fields[label] = Raw.Field(value: value)
        }
        
        return fields
    }
}
