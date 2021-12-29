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

import CustomDump
@testable import TalkToCloud
import XCTest

final class FilterEncodeTests: XCTestCase {
    func testEqualsIntEncoding() throws {
        let checked: Filter = .equals("tmdbID", 123)
        let expected =
        """
        {
          "fieldName" : "tmdbID",
          "fieldValue" : {
            "value" : 123
          },
          "comparator" : "EQUALS"
        }
        """
        try AssertEncoded(object: checked, expected: expected)
    }
    
    func testAndEncoding() throws {
        let checked: Filter = .and([.equals("tmdbID", 123), .in("recordName", ["fake", "bake", "shake"])])
        let expected =
        """
        [
          {
            "fieldName" : "tmdbID",
            "fieldValue" : {
              "value" : 123
            },
            "comparator" : "EQUALS"
          },
          {
            "fieldName" : "recordName",
            "fieldValue" : {
              "value" : [
                "fake",
                "bake",
                "shake"
              ]
            },
            "comparator" : "IN"
          }
        ]
        """
        try AssertEncoded(object: checked, expected: expected)
    }

    private func AssertEncoded<Checked: Encodable>(object: Checked, expected: String, file: StaticString = #file, line: UInt = #line) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(object)
        let string = String(data: data, encoding: .utf8)
        XCTAssertNoDifference(expected, string, file: file, line: line)
    }
}
