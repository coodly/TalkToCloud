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

extension CloudContainer {
    public func listZones(completion: @escaping ((Result<[CloudZone], Error>) -> Void)) {
        let request = ListZonesRequest(variables: variables)
        let handler: ((Result<CloudZonesList, Error>) -> Void) = {
            result in
            
            switch result {
            case .success(let list):
                completion(.success(list.zones))
            case .failure(let error):
                completion(.failure(error))
            }
        }
        request.perform(completion: handler)
    }
    
    
    public func create(zone named: String, completion: @escaping ((Result<CloudZone, Error>) -> Void)) {
        let request = CreateZoneRequest(name: named, variables: variables)
        request.perform() {
            result in
            
            switch result {
            case .success(let list):
                completion(.success(list.zones.first!))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    internal func checZonesExist(_ zones: [CloudZone]) {
        
    }
}
