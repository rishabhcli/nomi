# Shared/ Codable alignment

Swift types in `Sources/MnemoOrchestrator/` mirror engine JSON **at the client boundary only**. Internal view models may add fields; wire format must not drift.

## SourceLocator / Retrieved

| Swift | JSON key | Type |
|-------|----------|------|
| `docId` | `doc_id` | String |
| `path` | `path` | String |
| `title` | `title` | String |
| `charStart` | `char_start` | Int |
| `charEnd` | `char_end` | Int |

**Test:** `ProductDocTests.testSourceLocatorCodingKeys`, `EngineClientTests.testDecodesSearchResults`.

## MemoryEntry

| Swift | JSON key | Notes |
|-------|----------|-------|
| `id` | `id` | Engine memory id |
| `memory` | `memory` | Fact text |
| `version` | `version` | Monotonic |
| `isLatest` | `isLatest` | Only latest in answers |
| `isForgotten` | `isForgotten` | Excluded when true |
| `isStatic` | `isStatic` | Profile static chip |
| `parentMemoryId` | `parentMemoryId` | Supersession chain |
| `rootMemoryId` | `rootMemoryId` | Version root |
| `forgetAfter` | `forgetAfter` | ISO8601 TTL |
| `forgetReason` | `forgetReason` | Audit string |
| `history` | `history` | `[MemoryVersion]` |
| `documentIds` | `documentIds` | Provenance docs |

**Test:** `ProductDocTests.testMemoryEntryDecodesEngineJSON`, `MemoryDynamicsTests`.

## SourceCard (UI-only, not engine wire)

Built from `Retrieved` at query boundary. Fields: `title`, `path`, `docId`, `snippet?`, `relevance`, `updatedAt?`.

## QueryEvent / TerminalState

Not engine JSON — internal stream protocol. Documented in `QueryService.swift`. Every `TerminalState` maps to `NotchReducer.message(for:)` (AT-M12.7).

## Contract enforcement

`ProductDocContract.sourceLocatorCodingKeys` and `memoryEntryCodingKeys` mirror this doc. Run:

```bash
swift test --filter ProductDocTests
```
