# release_description

`release_description` stores one bounded, non-empty UTF-8 `String` — the
paragraph a release says about itself — on a `miso_music::release::Release`. The
prose is stored exactly as supplied: whitespace, case, line breaks, and
multi-byte UTF-8 are not normalized.

## Storage

One module-owned `ExtensionKey()` dynamic field on the release's `UID`, whose
value is the `String` itself. No wrapper struct, no other keys.

## API

All writes require the release's `ReleaseAdminCap` and go through the
cap-gated `release::uid_mut`; views are permissionless.

| Function | Description | Aborts |
|---|---|---|
| `set_description(release, cap, description: String)` | Sets or replaces the description, verbatim. Setting the value already stored neither writes nor emits. | `EEmptyDescription` (1), then `EDescriptionTooLong` (2) past 8192 bytes — both before cap authorization; then wrong cap (`release::EUnauthorized`, 0) |
| `clear_description(release, cap)` | Removes the description; an absent description is a silent no-op | wrong cap (0), even when nothing is attached |
| `has_description(release): bool` | Whether a description is attached | — |
| `description(release): &String` | The description | `ENoDescription` (0) when absent |

The 8192-byte bound is on bytes, not characters. Long-form writing belongs in
a Walrus blob referenced by an extension.

## Events

Both events carry only the release id. The description can be up to 8 KB, so
under the repository's event payload rule it is not repeated in the event; an
indexer reads it from the release's dynamic field after a set event.

| Event | Fields | BCS size |
|---|---|---|
| `ReleaseDescriptionSetEvent` | `release_id: ID` | 32 |
| `ReleaseDescriptionClearedEvent` | `release_id: ID` | 32 |

A set event is emitted only when the stored value actually changes; a cleared
event only when a description was actually removed. Views emit nothing.

## Errors

| Code | Constant | Location | Condition |
|---|---|---|---|
| 0 | `ENoDescription` | `release_description::release_description` | `description` with nothing attached |
| 1 | `EEmptyDescription` | `release_description::release_description` | `set_description` with an empty string |
| 2 | `EDescriptionTooLong` | `release_description::release_description` | `set_description` with more than 8192 bytes |
| 0 | `EUnauthorized` | `miso_music::release` | any write with a cap for a different release |

## Dependencies

- [`miso_music`](https://github.com/misofm/music-protocol) at
  `e676920b70e03cd2de8a52f440374d88d17d063f` — `Release`, `ReleaseAdminCap`,
  and cap-gated `uid_mut`.

## Publishing

`Published.toml` records the previously deployed generation. This generation
is published as a fresh immutable package identity and never upgraded in
place; clients migrate explicitly.

## Build and test

Run from this directory:

```sh
sui move build
sui move build --build-env mainnet
sui move test
sui move test --build-env mainnet
```
