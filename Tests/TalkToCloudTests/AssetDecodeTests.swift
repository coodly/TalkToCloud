import Foundation
@testable import TalkToCloud
import Testing

@Test func assetDecode() async throws {
  let response = try JSONDecoder().decode(Raw.Response.self, from: json.data(using: .utf8)!)
  let cursor = RecordsCursor(
    records: response.received,
    deleted: response.deleted,
    errors: response.errors,
    moreComing: false,
    syncToken: nil,
    nextPage: { nil }
  )

  struct ListPosterPull: CloudDecodable {
    static let recordType = "ListPoster"
    
    var recordName: String
    var recordChangeTag: String
    var deleted: Bool
    
    let key: String
    let poster: AssetFileDefinition?
  }

  let posters = cursor.records(of: ListPosterPull.self)
  #expect(posters.count == 1)
}

private let json =
"""
{
  "records" : [ {
    "recordName" : "CC5F5A5C-3007-40B2-AA38-DF3A10B1ED98",
    "recordType" : "ListPoster",
    "fields" : {
      "schemaVersion" : {
        "value" : "v1",
        "type" : "STRING"
      },
      "poster" : {
        "value" : {
          "fileChecksum" : "Ae0AvCHY4tmHAqhZ+G3/oTnypBr5",
          "size" : 1172645,
          "downloadURL" : "https://cvws.icloud-content.com/B/Ae0AvCHY4tmHAqhZ-G3_oTnypBr5/${f}?o=Ager_2nvBIvRLrCoBRTOfjdilv95znXFjVKda3uCK8VhnJYwD38ePJc4pQZBW8RifA&v=1&x=3&a=CAogKJiqweDlDuDWh5BcZGFLeOwunEOC0YriDh3s-GV6wLoShQEQ0La_t-UyGNCTm7nlMiIBAFIE8qQa-Wo1osbydEcJ3Hxc1wlPCYRvxey3UcMIGv2f7OWwxfBU9IkYppz6yvW4suJG6PVH1zRqy7hSRhdyNezBkEYFuomKjeI_fEVa61Sd50Y2oA62_E6tuKXn3GOszdxPfqQbGKdw-f9z_8Dc6AZeCdfU&e=1745218882&fl=&r=1e8f8318-9fb6-4350-9ecf-4c8b4ab14b7e-1&k=_&ckc=iCloud.com.coodly.moviez&ckz=_defaultZone&p=28&s=E3n9wbq4MKlkV0hi3pEa61tiMX8"
        },
        "type" : "ASSETID"
      },
      "key" : {
        "value" : "16187-75258-175112-9732-297270",
        "type" : "STRING"
      }
    },
    "pluginFields" : { },
    "recordChangeTag" : "kjstui7a",
    "created" : {
      "timestamp" : 1610385330636,
      "userRecordName" : "_4ab84f2560e93224e4c1b40e97b24ae5",
      "deviceID" : "2"
    },
    "modified" : {
      "timestamp" : 1655521220252,
      "userRecordName" : "_4ab84f2560e93224e4c1b40e97b24ae5",
      "deviceID" : "2"
    },
    "deleted" : false
  } ]
}
"""
