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
    private let sourceToken: ZoneTokenStore
    internal init(source: CloudContainer, target: CloudContainer, sourceToken: ZoneTokenStore) {
        self.source = source
        self.target = target
        self.sourceToken = sourceToken
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
                var targetZonesCount = 0
                for zone in zones {
                    if existing.contains(where: { $0.name == zone.name }) {
                        targetZonesCount += 1
                        continue
                    }
                    
                    Logging.log("Create zone named \(zone.name)")
                    self.target.create(zone: zone.name) {
                        result in
                        
                        switch result {
                        case .success(let created):
                            Logging.log("Created zone named \(created.name)")
                            targetZonesCount += 1
                        case .failure(let error):
                            Logging.error("Create target zone error \(error)")
                        }
                    }
                }
                
                guard targetZonesCount == zones.count else {
                    Logging.error("Missing target zones?")
                    return
                }
                
                self.performCopy(of: zones.filter({ $0.name != CloudZone.defaultZone.name }))
            case .failure(let error):
                Logging.error("List target zones error \(error)")
            }
        }
    }
    
    private func performCopy(of zones: [CloudZone]) {
        Logging.log("Copy records in zones \(zones.map(\.name).sorted())")
        guard zones.count == 1, let zone = zones.first else {
            fatalError("Single zone copy at the moment")
        }
        
        source.changes(in: zone, since: sourceToken.knownToken(in: zone)) {
            result in
            
            switch result {
            case .failure(let error):
                Logging.error("List changes error \(error)")
            case .success(let cursor):
                Logging.log("Retrieved \(cursor.records.count) records and \(cursor.deleted.count) deletions")
                self.write(records: cursor.records, into: zone)
            }
        }
    }
    
    private func write(records: [Raw.Record], into zone: CloudZone) {
        Logging.log("Write \(records.count) records into \(zone.name)")
        let saved = records.map({ Raw.SavedRecord(record: $0, withChange: false) })
        let operations = saved.map({ Raw.Operation.create.with(record: $0) })
        let body = Raw.Body(zone: zone, operations: operations)
        target.recordsModify(body: body, in: .private) {
            result in
            
            switch result {
            case .failure(let error):
                Logging.error("Save records error: \(error)")
            case .success(let cursor):
                Logging.log("Records saved \(cursor.records.count)")
                Logging.log("Record errors \(cursor.errors.count)")
            }
        }
    }
}
