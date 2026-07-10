# Inspector UX spec (M9)

Memory inspector: read, delete, correct. Effects visible on **next query** without rebuild.

## Entry

- Settings → Memory Inspector, or command `/inspect`
- Loads `ProfileSnapshot` from `MemoryInspector.snapshot()`

## Layout

```
┌─────────────────────────────────────┐
│  Memory Inspector                   │
├─────────────────────────────────────┤
│  STATIC (identity)                  │
│  [chip] User is a Rust engineer.    │
│  [chip] …                           │
├─────────────────────────────────────┤
│  DYNAMIC (inferred)                 │
│  [chip] User is migrating to Bazel. │
│  [chip] …                           │
└─────────────────────────────────────┘
```

| Chip type | `isStatic` | Behavior |
|-----------|------------|----------|
| Static | `true` | Long-lived identity facts |
| Dynamic | `false` | Inferred from documents |

**Test:** `InspectorTests.testSnapshotSplitsStaticAndDynamicChips` (AT-M9.1).

## Actions

### Delete

1. User taps ✕ on chip
2. `MemoryInspector.delete(id, text:)` → `forgetMemory` + `SuppressionLedger.suppress`
3. Next query excludes fact (AT-M9.2, BS-M6, BS-M12 step ⑥)

### Correct

1. User edits chip text
2. `MemoryInspector.correct(id, newText:)` → M6 supersede
3. Old version retained in history; new version is `isLatest`

**Test:** `InspectorTests.testCorrectSupersedes`.

## Suppression ledger

- Path: configurable; persists normalized + fuzzy keys
- Survives app restart and re-ingest
- **Test:** `SuppressionLedgerTests`, `SuppressionInIngestTests`

## Privacy

- No info-level logging of chip text (`InspectorLoggingAuditTests`)
- All inspector data stays on device

## BS-M12 integration

Step ⑤⑥: open inspector → delete Bazel fact → re-ask → answer no longer mentions Bazel.

## Accessibility

- Each chip: VoiceOver label = fact text + type (static/dynamic)
- Delete: "Remove from memory"
- Correct: "Edit fact"
