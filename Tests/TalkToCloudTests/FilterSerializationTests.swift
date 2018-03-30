//
//  FilterSerializationTests.swift
//  TalkToCloud
//
//  Created by Jaanus Siim on 30/03/2018.
//

import XCTest
@testable import TalkToCloud

class FilterSerializationTests: XCTestCase {
    func testSimpleValueSerialization() {
        let checked: Filter = .equals("tmdbID", 123 as AnyObject)
        let expected = ["comparator": "EQUALS", "fieldName": "tmdbID", "fieldValue": ["value": 123]] as AnyObject
        AssertDictionariesEqual(expected as? [AnyHashable: Any?], checked.json() as? [AnyHashable: Any?])
    }
    
    func testReferenceSerialization() {
        let checked: Filter = .equals("cake", RemoteReference(recordName: "cake-name") as AnyObject)
        let expected = ["comparator": "EQUALS", "fieldName": "cake", "fieldValue": ["value": ["recordName": "cake-name", "action": "DELETE_SELF"]]] as AnyObject
        AssertDictionariesEqual(expected as? [AnyHashable: Any?], checked.json() as? [AnyHashable: Any?])
    }
    
    private func AssertDictionariesEqual(_ expected: [AnyHashable: Any?]?, _ checked: [AnyHashable: Any?]?, file: StaticString = #file, line: UInt = #line) {
        guard let left = expected, let right = checked else {
            XCTAssertNotNil(expected, file: file, line: line)
            XCTAssertNotNil(checked, file: file, line: line)
            return
        }
        
        guard left.count == right.count else {
            XCTAssertFalse(true, "Checked dictionaries have different sizes: \(left.keys) - \(right.keys)", file: file, line: line)
            return
        }
        
        for (key, value) in left {
            guard let rightValue = right[key] else {
                XCTAssertFalse(true, "Checked missing value for \(key)", file: file, line: line)
                continue
            }
            
            if let dictLeft = value as? [AnyHashable: Any?], let dictRight = rightValue as? [AnyHashable: Any?] {
                AssertDictionariesEqual(dictLeft, dictRight, file: file, line: line)
            } else {
                XCTAssertEqual(value.debugDescription, rightValue.debugDescription, file: file, line: line)
            }
        }
    }
}
