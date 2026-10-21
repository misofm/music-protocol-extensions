# Security review — `recording_version`

Pre-publication qualification, 2026-10-20. This package is unpublished: there
is no `Published.toml`. See `Move.toml`, `README.md`, and the tests for the
current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `c5a4a3f78eca20c225ff702750b54da5c754fe4c`.

## Threat model

Set and clear go through `Recording::uid_mut`, which requires the
`RecordingAdminCap` of the recording's share type, including the equal-set
and absent-clear paths. `set_version` rejects an empty string
(`EEmptyVersion`, 1) and more than 300 bytes (`EVersionTooLong`, 2) before
authorization, so an invalid replacement leaves the stored value untouched.
The bound is on bytes, not characters. The module-owned key prevents
cross-extension collisions. No funds, custody, or external calls are
involved. Set events are at most 334 BCS bytes; clear events are 32.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 18/18 tests with no warnings and 100.00% coverage. Tests cover the
published/shared lifecycle with a stranger reader, the inclusive 1- and
300-byte bounds, a 300-byte three-byte-UTF-8 value accepted and 303 bytes
rejected, empty and over-long values, invalid replacements leaving storage
intact, equal-set and absent-clear silence, per-recording isolation, and
exact event BCS layouts.
