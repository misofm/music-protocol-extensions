# Security review — `recording_credits`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `1538d77035c4fb6b45b74f7d85168b7c3a80564b`,
`miso_party` at `8e59a815dc1129166b66a76d568edb8822859255`, and `credit` at
`a5ad1f65e0ef905d204857b519aaa7964abd5d0f`. `credit` provides
`Credit<RecordingPartyRole>`; `miso_party` provides only the credited `Party`
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

`RecordingCreditAddedEvent` carries the stored credit (display name and
roles): up to 1,307 bytes for a 200-byte display name and ten instrumentalist
roles with 100-byte instrument names.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 47/47 tests with no warnings, and both modules report 100.00%
coverage. Tests cover the published/shared lifecycle with a stranger reader,
every capacity bound and its precedence over duplicate and membership checks,
designation conflicts, not-designated removals, absent-record aborts on every
mutator, cascades and their event order, record removal and re-creation,
per-recording isolation, role BCS encoding, instrument validation, and exact
event sizes including the 1,105-byte maximum.
