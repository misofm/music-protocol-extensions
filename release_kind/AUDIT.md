# Security review — `release_kind`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`,
and the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `a62de87ff9c24c692ba711855b5acd94c4a6472e`.

## Threat model

Set and clear go through `Release::uid_mut`, which aborts
`release::EUnauthorized` for a cap of another release, including on absent
clears. `set_kind` rejects an empty string (`EEmptyKind`, 1) and more than 32
bytes (`EKindTooLong`, 2) before authorization. The value is stored verbatim
under a module-owned key and has no economic or authorization meaning. Set
events carry the release id and the value (at most 65 BCS bytes); clear
events carry the release id (32). Equal sets, absent clears, and views emit
nothing. No funds, custody, or external calls are involved.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 21/21 tests with no warnings and 100.00% coverage. Tests cover the
published/shared lifecycle with distinct senders, foreign caps on set and on clear (absent and present), validation-before-authorization, the exact
32-byte and byte-versus-character bounds, verbatim storage, equal-set and
absent-clear silence, per-release isolation, and exact event BCS layouts.
