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

@testable import TalkToCloud
import XCTest

final class RecordDecodeTests: XCTestCase {
    func testMappingDecode() throws {
        struct Mapping: CloudDecodable {
            static var recordType: String {
                "Mapping"
            }
            
            var recordName: String
            var recordChangeTag: String
            var deleted: Bool
            
            let autoStatus: String?
            let status: Int64?
        }
        
        let data = recordJSON.data(using: .utf8)!
        let raw = try JSONDecoder().decode(Raw.Record.self, from: data)
        XCTAssertNotNil(raw)
        
        let recordDecoder = RecordDecoder()
        recordDecoder.record = raw
        
        let mapping = try Mapping(from: recordDecoder)
        XCTAssertNotNil(mapping)
        XCTAssertEqual("checked", mapping.autoStatus)
        XCTAssertEqual(1, mapping.status)
    }
}

private let recordJSON =
"""
{
  "recordName": "2F95E45A-3900-4BF3-86D2-85F139AD3F15",
  "recordType": "Mapping",
  "fields": {
    "country": {
      "value": "US",
      "type": "STRING"
    },
    "checkedAt": {
      "value": 1638605892474,
      "type": "TIMESTAMP"
    },
    "schemaVersion": {
      "value": "v1",
      "type": "STRING"
    },
    "tmdbID": {
      "value": 249333,
      "type": "INT64"
    },
    "autoStatus": {
      "value": "checked",
      "type": "STRING"
    },
    "name": {
      "value": "An Innocent Affair",
      "type": "STRING"
    },
    "availability": {
      "value": 2,
      "type": "INT64"
    },
    "status": {
      "value": 1,
      "type": "INT64"
    }
  },
  "pluginFields": {},
  "recordChangeTag": "j7if0cac",
  "created": {
    "timestamp": 1505270195464,
    "userRecordName": "_6936fa6af985df311dcf19d47271a5ff",
    "deviceID": "4A85A6AA5FFDB65C706870365B4B49B7820EE270E5F9433BF77485A8F04F826C"
  },
  "modified": {
    "timestamp": 1638605897637,
    "userRecordName": "_4ab84f2560e93224e4c1b40e97b24ae5",
    "deviceID": "2"
  },
  "deleted": false,
  "zoneID": {
    "zoneName": "_defaultZone",
    "ownerRecordName": "_4ab84f2560e93224e4c1b40e97b24ae5",
    "zoneType": "DEFAULT_ZONE"
  }
}
"""
