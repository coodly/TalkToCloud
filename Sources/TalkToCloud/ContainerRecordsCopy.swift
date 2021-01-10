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
                self.write(records: cursor.records, into: zone) {
                    result in
                    
                    switch result {
                    case .failure(let error):
                        Logging.error("Write changes error: \(error)")
                    case .success(_):
                        self.processNextBatch(in: cursor)
                    }
                }
            }
        }
    }
    
    private func processNextBatch(in cursor: RecordsCursor) {
        Logging.log("Process next batch")
        guard cursor.moreComing else {
            Logging.log("No more changes in source")
            return
        }
        
        cursor.continuation?()
    }
    
    private func write(records: [Raw.Record], into zone: CloudZone, completion: @escaping ((Result<Bool, Error>) -> Void)) {
        Logging.log("Write \(records.count) records into \(zone.name)")
        let saved = records.map({ Raw.SavedRecord(record: $0, withChange: false) })
        let operations = saved.map({ Raw.Operation(record: $0) })
        let body = Raw.Body(zoneID: zone.zoneID, operations: operations)
        target.recordsModify(body: body, in: .private) {
            result in
            
            switch result {
            case .failure(let error):
                Logging.error("Save records error: \(error)")
                completion(.failure(error))
            case .success(let cursor):
                Logging.log("Records saved \(cursor.records.count)")
                Logging.log("Record errors \(cursor.errors.count)")
                self.resolve(errors: cursor.errors, on: records, in: zone, completion: completion)
            }
        }
    }
    
    private func resolve(errors: [Raw.RecordError], on records: [Raw.Record], in zone: CloudZone, completion: @escaping ((Result<Bool, Error>) -> Void)) {
        let conflicts = errors.filter(\.isConflict)
        if conflicts.count == 0 {
            completion(.success(true))
            return
        }

        Logging.log("Have \(conflicts.count) conflicts")
        
        let names = conflicts.map(\.recordName)
        target.codedLookup(of: names, zone: zone, in: .private) {
            result in
            
            switch result {
            case .failure(let error):
                Logging.log("Lookup error \(error)")
                completion(.failure(error))
            case .success(let cursor):
                Logging.log("Lookup returned \(cursor.records.count) records")
                self.modify(records: cursor.records, with: records, in: zone, completion: completion)
            }
        }
    }
    
    private func modify(records: [Raw.Record], with original: [Raw.Record], in zone: CloudZone, completion: @escaping ((Result<Bool, Error>) -> Void)) {
        var modified = [Raw.SavedRecord]()
        for record in records {
            guard let source = original.first(where: { $0.recordName == record.recordName }) else {
                continue
            }
            
            let saved = Raw.SavedRecord(record: record, withChange: true).replacing(fields: source.fields)
            modified.append(saved)
        }
        
        guard modified.count > 0 else {
            completion(.success(true))
            return
        }
        
        Logging.log("Will save \(modified.count) refreshed records")
        let operations = modified.map({ Raw.Operation(record: $0) }).first!
        let body = Raw.Body(zoneID: zone.zoneID, operations: [operations])
        target.recordsModify(body: body, in: .private) {
            result in
            
            switch result {
            case .failure(let error):
                Logging.error("Modify error \(error)")
                completion(.failure(error))
            case .success(let cursor):
                Logging.log("Modified \(cursor.records.count) records")
                if cursor.errors.count > 0 {
                    Logging.error("Had \(cursor.errors.count) errors")
                    cursor.errors.forEach({ Logging.error($0) })
                }
                
                completion(.success(true))
            }
        }
    }
}
