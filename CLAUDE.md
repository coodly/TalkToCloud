# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Build the package
swift build

# Run tests
swift test

# Run a single test
swift test --filter TalkToCloudTests.RecordDecodeTests/testMappingDecode
```

## Architecture

TalkToCloud is a Swift library for server-to-server CloudKit communication via Apple's CloudKit Web Services API.

### API Layers

**New Async API** (preferred):
```
CloudKit -> Container -> Database -> Zone
```
- `CloudKit` - Entry point providing `development` and `production` containers
- `Container` - Provides `public` and `private` databases
- `Database` - Provides `default` zone or custom zones via `zone(name:)`
- `Zone` - Async methods for CRUD: `query()`, `modify()`, `delete()`, `lookup()`, `upload()`

**Legacy Callback API** (being phased out):
- `CloudContainer` - Callback-based API with similar operations
- `Commander<Command>` - CLI runner with container consumer protocols

### Record Protocols

- `CloudDecodable` - Modern Decodable-based protocol with `RecordDecoder`
- `CloudEncodable` - Encodable protocol for serializing to CloudKit format
- `RemoteRecord` - Legacy protocol using Mirror reflection (callback API)

### Authentication

- `PrivateKeyAuthenticator` - Server-to-server auth using ECDSA signatures
- `TokenAuthenticator` - Web token-based auth for user sessions

### Raw Namespace

Codable structs mapping directly to CloudKit Web Services JSON:
- `Raw.Record`, `Raw.Field`, `Raw.ZoneID`, `Raw.Operation`, `Raw.Request`, `Raw.Response`, etc.

### Configuration

Credentials are loaded from `Config/` directory:
- `{container-id}-{environment}.key` - API Key ID from CloudKit Dashboard
- `{container-id}-{environment}.pem` - Private key file
