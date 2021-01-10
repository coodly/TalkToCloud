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

internal class ContainerRecordsCopy {
    private let source: CloudContainer
    private let target: CloudContainer
    internal init(source: CloudContainer, target: CloudContainer) {
        self.source = source
        self.target = target
    }
    
    internal func execute() {
        listSourceZones()
    }
    
    private func listSourceZones() {
        Logging.log("List source zones")
        source.listZones() {
            result in
            
            switch result {
            case .success(let zones):
                Logging.log("Source has zones \(zones.map(\.name).sorted())")
                self.checkTargetZones(with: zones)
            case .failure(let error):
                Logging.log("List source zones error: \(error)")
            }
        }
    }
    
    private func checkTargetZones(with zones: [CloudZone]) {
        Logging.log("Check target zones")
        target.listZones() {
            result in
            
            switch result {
            case .success(let existing):
                Logging.log("Target has zones \(existing.map(\.name).sorted())")
                for zone in zones {
                    if existing.contains(where: { $0.name == zone.name }) {
                        continue
                    }
                    
                    Logging.log("Create zone named \(zone.name)")
                    self.target.create(zone: zone.name) {
                        result in
                        
                        switch result {
                        case .success(let created):
                            Logging.log("Created zone named \(created.name)")
                        case .failure(let error):
                            Logging.error("Create target zone error \(error)")
                        }
                    }
                }
            case .failure(let error):
                Logging.error("List target zones error \(error)")
            }
        }
    }
}
