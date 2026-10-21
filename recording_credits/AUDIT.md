# Security review — `recording_credits`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `musicos` at `24570431c1c02118c2b558d4ac1c30b39ca4cb2f`,
`partyos` at `88c2e40353dbee8d8f98272069b4d836b02b12ae`, and `credit` at
`6c295ea10f796edfec18f54783733a35210f4b06`. `credit` provides
`Credit<RecordingPartyRole>`; `partyos` provides only the credited `Party`
identity.

## Threat model

All six mutations go through `Recording::uid_mut`, which requires the
`RecordingAdminCap` of the recording's share type. Module-owned keys and
private stored fields protect the dynamic-field schema. The implementation
enforces unique credited parties, bounded credits (150), roles (10),
primary (20) and featured (50) artists, designation only of credited parties,
and disjoint primary and featured sets. Removing a credit cascades through
both designations, emitting each artist-removed event before the
credit-removed event, and removing the last credit removes the record, so
presence means at least one credit. Credits are administrator-authored
attribution and never drive royalty accounting. Views and constructors are
silent. No funds, custody, or external calls are involved.

`RecordingCreditAddedEvent` carries the stored roles: 66 bytes typically, up
to 1,105 bytes for ten instrumentalist roles with 100-byte instrument names.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 47/47 tests with no warnings, and both modules report 100.00%
coverage. Tests cover the published/shared lifecycle with a stranger reader,
every capacity bound and its precedence over duplicate and membership checks,
designation conflicts, not-designated removals, absent-record aborts on every
mutator, cascades and their event order, record removal and re-creation,
per-recording isolation, role BCS encoding, instrument validation, and exact
event sizes including the 1,105-byte maximum.
