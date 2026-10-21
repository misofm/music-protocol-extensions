# Security review — `recording_advisory`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `musicos` at `24570431c1c02118c2b558d4ac1c30b39ca4cb2f`.

## Threat model

The relevant threat is an unauthorized advisory change. Set and clear go
through `Recording::uid_mut`, which requires the `RecordingAdminCap` of the
recording's share type, including the equal-set and absent-clear paths.
`ExtensionKey` is module-owned and the stored value is a closed enum, so
malformed or cross-extension values cannot enter through this API. Absence,
`NotExplicit`, and `Cleaned` remain distinct; `advisory` aborts `ENoAdvisory`
(0) rather than defaulting. No funds, custody, or external calls are
involved. Events are 33 (set) and 32 (clear) BCS bytes; equal sets and absent
clears emit nothing.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 13/13 tests with no warnings and 100.00% coverage, including the
published/shared lifecycle with distinct senders, every transition between
the three values, equal sets, absent and repeated clears, per-recording
isolation, exact event payloads, and the absence abort.
