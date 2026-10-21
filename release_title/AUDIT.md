# Security review — `release_title`

Pre-publication qualification, 2026-10-20. This package is unpublished: there
is no `Published.toml`. See `Move.toml`, `README.md`,
and the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `aae43b34a5b6fe97201ecdb5e9c520cebfc79450`.

## Threat model

Set and clear go through `Release::uid_mut`, which aborts
`release::EUnauthorized` for a cap of another release, including on absent
clears. `set_title` rejects an empty string (`EEmptyTitle`, 1) and more than 300
bytes (`ETitleTooLong`, 2) before authorization. The value is stored verbatim
under a module-owned key and has no economic or authorization meaning. Set
events carry the release id and the value (at most 334 BCS bytes); clear
events carry the release id (32). Equal sets, absent clears, and views emit
nothing. No funds, custody, or external calls are involved.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 20/20 tests with no warnings and 100.00% coverage. Tests cover the
published/shared lifecycle with distinct senders, foreign caps on set and on clear (absent and present), validation-before-authorization, the exact
300-byte and byte-versus-character bounds, verbatim storage, equal-set and
absent-clear silence, per-release isolation, and exact event BCS layouts.
