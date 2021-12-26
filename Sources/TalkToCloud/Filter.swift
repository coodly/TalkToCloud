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

public struct Filter: Codable {
    let single: Raw.RecordsFilter?
    let combined: [Raw.RecordsFilter]?
    
    public init(from decoder: Decoder) throws {
        fatalError()
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let single = single {
            try container.encode(single)
        } else if let combined = combined {
            try container.encode(combined)
        } else {
            fatalError()
        }
    }
}

extension Filter {
    internal init(single: Raw.RecordsFilter) {
        self.single = single
        self.combined = nil
    }
    
    internal init(combined: [Raw.RecordsFilter]) {
        self.single = nil
        self.combined = combined
    }
}

extension Filter {
    public static func equals<Value: Codable>(_ field: String, _ value: Value) -> Filter {
        Filter(single: Raw.RecordsFilter(fieldName: field, comparator: .equals, fieldValue: .init(any: value)))
    }
    public static func notEquals<Value: Codable>(_ field: String, _ value: Value) -> Filter {
        Filter(single: Raw.RecordsFilter(fieldName: field, comparator: .notEquals, fieldValue: .init(any: value)))
    }
    public static func `in`<Value: Codable>(_ field: String, _ value: Value) -> Filter {
        Filter(single: Raw.RecordsFilter(fieldName: field, comparator: .in, fieldValue: .init(any: value)))
    }
    public static func lt<Value: Codable>(_ field: String, _ value: Value) -> Filter {
        Filter(single: Raw.RecordsFilter(fieldName: field, comparator: .lessThan, fieldValue: .init(any: value)))
    }
    public static func lte<Value: Codable>(_ field: String, _ value: Value) -> Filter {
        Filter(single: Raw.RecordsFilter(fieldName: field, comparator: .lessThanOrEquals, fieldValue: .init(any: value)))
    }
    public static func gt<Value: Codable>(_ field: String, _ value: Value) -> Filter {
        Filter(single: Raw.RecordsFilter(fieldName: field, comparator: .greaterThan, fieldValue: .init(any: value)))
    }
    public static func gte<Value: Codable>(_ field: String, _ value: Value) -> Filter {
        Filter(single: Raw.RecordsFilter(fieldName: field, comparator: .greaterThanOrEquals, fieldValue: .init(any: value)))
    }
    
    public static func and(_ filters: [Filter]) -> Filter {
        Filter(combined: filters.compactMap(\.single))
    }
}
