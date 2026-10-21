# Security review — `recording_credits`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `a62de87ff9c24c692ba711855b5acd94c4a6472e`,
`miso_party` at `9374c6eed64c907722ac1c93813c76dc7912b357`, and `credit` at
`c8d5be0a462760c74b45dcdc39a3e5e0a2f10b99`. `credit` provides
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
