/*
 * Copyright 2018 Coodly LLC
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

internal struct AssetUploadCreate: Encodable {
    internal let tokens: [AssetUploadToken]
    internal init(asset: AssetUpload) {
        tokens = [AssetUploadToken(recordName: asset.recordName, recordType: asset.recordType, fieldName: asset.fieldName)]
    }
}

internal struct AssetUploadToken: Encodable {
    internal let recordName: String?
    internal let recordType: String
    internal let fieldName: String
}

internal struct AssetCreateResponse: Decodable {
    internal let tokens: [AssetUploadTarget]
}

internal struct AssetUploadTarget: Decodable {
    internal let recordName: String
    internal let fieldName: String
    internal let url: URL
}

internal struct AssetUploadResponse: Decodable {
    internal let singleFile: AssetFileDefinition
}

public struct AssetFileDefinition: Decodable {
    let wrappingKey: String?
    let fileChecksum: String
    let receipt: String
    let referenceChecksum: String?
    let size: Int
    
    internal func dictionary() -> [String: AnyObject] {
        var result = [String: AnyObject]()
        let mirror = Mirror(reflecting: self)
        for child in mirror.children {
            if let value = child.value as? String {
                result[child.label!] = value as AnyObject
            } else if let value = child.value as? Int {
                result[child.label!] = value as AnyObject
            }
        }
        return result
    }
}
