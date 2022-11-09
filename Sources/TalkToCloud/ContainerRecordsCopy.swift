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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

internal class ContainerRecordsCopy {
    private let source: CloudContainer
    private let target: CloudContainer
    private let sourceToken: ZoneTokenStore
    private let chunked: Bool
    private let order: (([CloudZone]) -> [CloudZone])
    internal init(
        source: CloudContainer,
        target: CloudContainer,
        sourceToken: ZoneTokenStore,
        chunked: Bool,
        copyOrder: @escaping (([CloudZone]) -> [CloudZone])
    ) {
        self.source = source
        self.target = target
        self.sourceToken = sourceToken
        self.chunked = chunked
        self.order = copyOrder
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
        let ordered = order(zones)
        Logging.log("Copy order \(ordered.map(\.name))")
        ordered.forEach(performCopy(of:))
    }
    
    private func performCopy(of zone: CloudZone) {
        Logging.log("Perform copy of \(zone.name)")
        
        source.changes(in: zone, since: sourceToken.knownToken(in: zone)) {
            result in
            
            switch result {
            case .failure(let error):
                Logging.error("List changes error \(error)")
            case .success(let cursor):
                Logging.log("Retrieved \(cursor.records.count) records and \(cursor.deleted.count) deletions")
                let chunked = self.maybeChunked(cursor.records)
                var deleted = cursor.deleted
                
                for chunk in chunked {
                    let recordsWithAssets = chunk.filter(\.containsAsset)
                    self.write(records: chunk.map(\.withoutAssets), deletions: deleted, into: zone) {
                        result in
                        
                        switch result {
                        case .failure(let error):
                            Logging.error("Write changes error: \(error)")
                        case .success(_):
                            self.copyAssets(recordsWithAssets, to: zone) {}
                        }
                    }
                    deleted.removeAll()
                    
                    if self.chunked {
                        Thread.sleep(forTimeInterval: 0.5)
                    }
                }

                self.sourceToken.mark(token: cursor.syncToken!, in: zone)
                self.processNextBatch(in: cursor)
            }
        }
    }
    
    private func copyAssets(_ records: [Raw.Record], to zone: CloudZone, completion: @escaping (() -> Void)) {
        Logging.log("Copy \(records.count) record assets")
        guard records.count > 0 else {
            completion()
            return
        }
        
        let names = records.map(\.recordName)
        var existing: [Raw.Record] = []
        target.codedLookup(of: names, zone: zone, in: .private) {
            result in
            
            switch result {
            case .success(let cursor):
                existing = cursor.records
            case .failure(let error):
                Logging.error(error)
                fatalError()
            }
        }
        Logging.log("\(existing.count) records from target")
        var saved = [Raw.Record]()
        for record in records {
            let inTarget = existing.first(where: { $0.recordName == record.recordName })!
            if let modified = copyAssets(in: record, as: inTarget, in: zone) {
                saved.append(modified)
            }
        }
        
        guard saved.count > 0 else {
            completion()
            return
        }
        
        self.write(records: saved, deletions: [], into: zone) {
            result in
            
            switch result {
            case .success(_):
                completion()
            case .failure(let error):
                Logging.error(error)
                fatalError()
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
    
    private func write(records: [Raw.Record], deletions: [Raw.RecordID], into zone: CloudZone, completion: @escaping ((Result<Bool, Error>) -> Void)) {
        Logging.log("Write \(records.count) records and \(deletions.count) deletions into \(zone.name)")
        guard records.count > 0 || deletions.count > 0 else {
            completion(.success(true))
            return
        }
        
        let saved = records.map({ Raw.SavedRecord(record: $0, withChange: false) })
        var operations = saved.map({ Raw.Operation(record: $0) })
        deletions.forEach() {
            delete in
            
            operations.append(Raw.Operation(delete: delete))
        }
        let body = Raw.Request(zoneID: zone.zoneID, operations: operations)
        target.recordsModify(body: body, in: .private) {
            result in
            
            switch result {
            case .failure(let error):
                Logging.error("Save records error: \(error)")
                completion(.failure(error))
            case .success(let cursor):
                Logging.log("Records saved \(cursor.records.count)")
                Logging.log("Records deleted \(cursor.deleted.count)")
                Logging.log("Record errors \(cursor.errors.count)")
                self.resolve(errors: cursor.errors, on: records, in: zone, completion: completion)
            }
        }
    }
    
    private func resolve(errors: [Raw.RecordError], on records: [Raw.Record], in zone: CloudZone, completion: @escaping ((Result<Bool, Error>) -> Void)) {
        if errors.count == 0 {
            Logging.log("No errors. Continue")
            completion(.success(true))
            return
        }
        
        let conflicts = errors.filter(\.isConflict)
        if conflicts.count == 0 {
            completion(.failure(CloudError.undefined))
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
                self.modify(conflicts: cursor.records, with: records, in: zone, completion: completion)
            }
        }
    }
    
    private func modify(conflicts: [Raw.Record], with original: [Raw.Record], in zone: CloudZone, completion: @escaping ((Result<Bool, Error>) -> Void)) {
        var modified = [Raw.SavedRecord]()
        for record in original {
            if let withConflict = conflicts.first(where: { $0.recordName == record.recordName }) {
                let saved = Raw.SavedRecord(record: withConflict, withChange: true).replacing(fields: record.fields)
                modified.append(saved)
            } else {
                modified.append(Raw.SavedRecord(record: record, withChange: false))
            }
        }
        guard modified.count == original.count else {
            completion(.failure(CloudError.undefined))
            return
        }
        
        Logging.log("Will save \(modified.count) refreshed records")
        let operations = modified.map({ Raw.Operation(record: $0) })
        let body = Raw.Request(zoneID: zone.zoneID, operations: operations)
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
    
    private func copyAssets(in inSource: Raw.Record, as inTarget: Raw.Record, in zone: CloudZone) -> Raw.Record? {
        var modifiedFields: [String: Raw.Field] = [:]
        for (name, field) in inSource.fields.filter({$1.type == .assetId}) {
            if let targetAsset = inTarget.fields[name]?.assetDownload, targetAsset.fileChecksum == field.assetDownload?.fileChecksum {
                Logging.log("Have matching checksum - \(targetAsset.fileChecksum)")
                continue
            }
            
            let downloadPath = field.assetDownload!.downloadURL!.replacingOccurrences(of: "${f}", with: "image.jpg")
            var data: Data?
            target.fetch.fetch(URLRequest(url: URL(string: downloadPath)!)) {
                loaded, _, _ in
                
                data = loaded
            }
            
            let upload = AssetUpload(recordName: inTarget.recordName, recordType: inTarget.recordType, fieldName: name, data: data!, zone: zone)
            let fileDefinition = target.upload(asset: upload, in: .private)
            var modifiedField = field
            modifiedField.assetDownload = fileDefinition
            modifiedFields[name] = modifiedField                    
        }
        
        guard modifiedFields.count > 0 else {
            Logging.log("No modifications needed on \(inSource.recordType):\(inSource.recordName)")
            return nil
        }
        
        return inTarget.updating(fields: modifiedFields)
    }
    
    private func maybeChunked(_ records: [Raw.Record]) -> [[Raw.Record]] {
        guard chunked else {
            return [records]
        }
        
        return records.chunked
    }
}

extension Array where Element == Raw.Record {
    fileprivate var chunked: [[Raw.Record]] {
        var result = [String: [Raw.Record]]()
        
        for record in self {
            if #available(macOS 12.0, *) {
                result[record.modified.date.ISO8601Format(), default: []].append(record)
            } else {
                fatalError()
            }
        }
        
        return result.keys.sorted().compactMap({ result[$0] })
    }
}
