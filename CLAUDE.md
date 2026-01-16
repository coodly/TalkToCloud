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

### Core Components

**CloudContainer** (`CloudContainer.swift`) - Main entry point for CloudKit operations. Handles CRUD operations (save, delete, fetch, lookup) against CloudKit databases. Supports public, private, and shared databases.

**Authentication** - Two authenticator types:
- `PrivateKeyAuthenticator` - Server-to-server auth using ECDSA signatures (requires .key and .pem files in Config/)
- `TokenAuthenticator` - Web token-based auth for user sessions

**Record Protocols**:
- `RemoteRecord` - Legacy protocol using Mirror reflection for field serialization
- `CloudDecodable` - Modern Decodable-based protocol with `RecordDecoder` for deserializing CloudKit records
- `CloudEncodable` - Encodable protocol for serializing to CloudKit format

**Network Layer**:
- `NetworkFetch` - Sendable struct wrapping async URLSession calls
- `Request<T>` - Base class for typed API requests
- Platform-specific fetch implementations: `AsyncSystemFetch` (macOS), `CommandLineFetch` (Linux via curl)

**Container Consumer Protocols** - Dependency injection pattern:
- `ContainerConsumer` - Single container, environment from CLI args
- `DevelopmentConsumer` / `ProductionConsumer` - Explicit environment containers

### Raw Namespace

The `Raw` namespace contains Codable structs that map directly to CloudKit Web Services JSON:
- `Raw.Record`, `Raw.Field`, `Raw.ZoneID`, `Raw.Operation`, etc.

### CLI Usage Pattern

The library is designed for CLI tools. Create a `Command` conforming type, use consumer protocols for container injection, and run via `Commander<YourCommand>`.

### Configuration

Credentials are loaded from `Config/` directory:
- `{container-id}-{environment}.key` - API Key ID from CloudKit Dashboard
- `{container-id}-{environment}.pem` - Private key file
