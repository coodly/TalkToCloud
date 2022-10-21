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

extension Raw {
    internal struct RecordsFilter: Codable {
        enum Comparator: String, Codable {
            case equals = "EQUALS"
            case notEquals = "NOT_EQUALS"
            case `in` = "IN"
            case lessThan = "LESS_THAN"
            case lessThanOrEquals = "LESS_THAN_OR_EQUALS"
            case greaterThan = "GREATER_THAN"
            case greaterThanOrEquals = "GREATER_THAN_OR_EQUALS"
        }

        struct Value: Codable {
            init(from decoder: Decoder) throws {
                fatalError()
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                if let value = string {
                    try container.encode(value, forKey: .value)
                } else if let value = stringList {
                    try container.encode(value, forKey: .value)
                } else if let value = double {
                    try container.encode(value, forKey: .value)
                } else if let value = doubleList {
                    try container.encode(value, forKey: .value)
                } else if let value = int64 {
                    try container.encode(value, forKey: .value)
                } else if let value = int64List {
                    try container.encode(value, forKey: .value)
                } else if let value = date {
                    try container.encode(value.milliseconds(), forKey: .value)
                } else {
                    dump(self)
                    fatalError()
                }
            }
            
            let string: String?
            let stringList: [String]?
            let double: Double?
            let doubleList: [Double]?
            let int64: Int64?
            let int64List: [Int64]?
            let date: Date?
            
            enum CodingKeys: String, CodingKey {
                case value
            }
        }

        let fieldName: String
        let comparator: Comparator
        let fieldValue: Value
    }
}

extension Raw.RecordsFilter.Value {
    init(any: Codable) {
        string = any as? String
        stringList = any as? [String]
        double = any as? Double
        doubleList = any as? [Double]
        date = any as? Date

        if let int = any as? Int {
            int64 = Int64(int)
        } else {
            int64 = any as? Int64
        }
        if let ints = any as? [Int] {
            int64List = ints.map({ Int64($0) })
        } else {
            int64List = any as? [Int64]
        }
    }
}
