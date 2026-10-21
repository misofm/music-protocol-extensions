# Security review — `recording_genre`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `musicos` at `24570431c1c02118c2b558d4ac1c30b39ca4cb2f` and
`genre` at `90baae2919f7272f6d4bbb245b643f7dba5dc0ba`.

## Threat model

All three mutations go through `Recording::uid_mut`, which requires the
`RecordingAdminCap` of the recording's share type, including the absent-clear
path. `add_genre` takes a `&Genre`, so only ids of real vocabulary entries
can enter; removal takes a bare `ID` and only removes. The list is unique,
bounded at six, and non-empty by construction: removing the last genre drops
the field, so `has_genres` means at least one genre, and `genres` aborts
`ENoGenres` rather than returning an empty list. The module-owned key prevents
cross-extension collisions. No funds, custody, or external calls are
involved. Events are 64 (add/remove) and 32 (clear) BCS bytes.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 18/18 tests with no warnings and 100.00% coverage. Tests cover the
published/shared lifecycle with a stranger reader, primary promotion on
removal, the six-genre bound, duplicate rejection, absent and not-found
removals, field removal with the last genre, clear-and-re-add reordering,
silent absent clears, an unrelated dynamic field left untouched, and exact
event BCS layouts.
