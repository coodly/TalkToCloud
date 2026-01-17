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

public struct ZoneRecordsCopy: Sendable {
  private let source: Zone
  private let target: Zone
  private let tokenStore: ZoneTokenStore
  private let chunked: Bool

  public init(source: Zone, target: Zone, tokenStore: ZoneTokenStore, chunked: Bool = false) {
    self.source = source
    self.target = target
    self.tokenStore = tokenStore
    self.chunked = chunked
  }

  public func execute() async throws {
    let cloudZone = CloudZone(name: source.name)
    let token = tokenStore.knownToken(in: cloudZone)
    try await copyRecords(since: token)
  }

  private func copyRecords(since token: String?) async throws {
    Logging.log("Copy records in \(source.name) since \(token ?? "nil")")

    let cursor = try await source.changes(since: token)

    Logging.log("Retrieved \(cursor.records.count) records and \(cursor.deleted.count) deletions")

    try await writeRecords(from: cursor)

    if let syncToken = cursor.syncToken {
      let cloudZone = CloudZone(name: source.name)
      tokenStore.mark(token: syncToken, in: cloudZone)
    }

    if cursor.moreComing, let nextCursor = try await cursor.nextPage() {
      try await processNextBatch(nextCursor)
    }
  }

  private func processNextBatch(_ cursor: RecordsCursor) async throws {
    Logging.log("Process next batch: \(cursor.records.count) records")

    try await writeRecords(from: cursor)

    if let syncToken = cursor.syncToken {
      let cloudZone = CloudZone(name: source.name)
      tokenStore.mark(token: syncToken, in: cloudZone)
    }

    if cursor.moreComing, let nextCursor = try await cursor.nextPage() {
      try await processNextBatch(nextCursor)
    }
  }

  private func writeRecords(from cursor: RecordsCursor) async throws {
    guard cursor.records.count > 0 || cursor.deleted.count > 0 else {
      Logging.log("No records to write")
      return
    }

    let chunks = chunkedRecords(cursor.records)
    var isFirstChunk = true

    for chunk in chunks {
      let chunkCursor = RecordsCursor(
        records: chunk,
        deleted: isFirstChunk ? cursor.deleted : [],
        errors: [],
        moreComing: false,
        syncToken: nil,
        nextPage: { nil }
      )

      let result = try await target.copyRecords(from: chunkCursor)

      Logging.log("Saved \(result.records.count) records")
      if isFirstChunk {
        Logging.log("Deleted \(result.deleted.count) records")
      }

      if result.errors.count > 0 {
        Logging.log("Errors: \(result.errors.count)")
        try await resolveErrors(result.errors, from: chunkCursor)
      }

      isFirstChunk = false

      if chunked && chunks.count > 1 {
        try await Task.sleep(for: .milliseconds(500))
      }
    }
  }

  private func chunkedRecords(_ records: [Raw.Record]) -> [[Raw.Record]] {
    guard chunked else {
      return [records]
    }

    var result = [String: [Raw.Record]]()

    for record in records {
      let key = record.modified.date.ISO8601Format()
      result[key, default: []].append(record)
    }

    return result.keys.sorted().compactMap({ result[$0] })
  }

  private func resolveErrors(_ errors: [Raw.RecordError], from cursor: RecordsCursor) async throws {
    let conflicts = errors.filter(\.isConflict)
    guard conflicts.count > 0 else {
      Logging.error("Non-conflict errors: \(errors.count)")
      return
    }

    Logging.log("Resolving \(conflicts.count) conflicts")

    let names = conflicts.map(\.recordName)
    let existing = try await target.lookup(names: names)

    var saved: [Raw.SavedRecord] = []
    for record in cursor.records {
      guard let withConflict = existing.records.first(where: { $0.recordName == record.recordName }) else {
        continue
      }
      var save = Raw.SavedRecord(record: record)
      save.recordChangeTag = withConflict.recordChangeTag
      saved.append(save)
    }

    let operations = saved.map(Raw.Operation.init(record:))
    let request = Raw.Request(zoneID: Raw.ZoneID(name: target.name), operations: operations)

    let result = try await target.post(to: "/records/modify", body: request)

    Logging.log("Resolved \(result.records.count) conflicts")
    if result.errors.count > 0 {
      Logging.error("Still have \(result.errors.count) errors after conflict resolution")
    }
  }
}
