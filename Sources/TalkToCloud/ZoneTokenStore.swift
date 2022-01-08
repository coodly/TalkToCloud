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

public struct ZoneTokenStore {
    private let onKnownToken: ((CloudZone) -> String?)
    private let onMarkToken: ((String, CloudZone) -> Void)
    
    public init(
        onKnownToken: @escaping ((CloudZone) -> String?),
        onMarkToken: @escaping ((String, CloudZone) -> Void)
    ) {
        self.onKnownToken = onKnownToken
        self.onMarkToken = onMarkToken
    }
    
    public func knownToken(in zone: CloudZone) -> String? {
        onKnownToken(zone)
    }
    
    public func mark(token: String, in zone: CloudZone) {
        onMarkToken(token, zone)
    }
}
