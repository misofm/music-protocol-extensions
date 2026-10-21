# Security review — `release_credits`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `f52e79db4f44e9c59f277c4291c2b167295d002b`,
`miso_party` at `65f22c8a0e8e32ac4ee52322536a15cbb5b0a429`, and `credit` at
`5aa56d788657f7438d85ae07862d07ebd3cb5f8c`.

## Threat model

Both mutations go through `Release::uid_mut`, which aborts
`release::EUnauthorized` for a cap of another release before any stored-state
check. The role count is validated before authorization. Parties are unique,
each credit carries exactly one role, and the credit count is bounded at 50.
The record is removed with its last credit, so presence means at least one
credit. The module-owned key and private fields prevent cross-extension
collisions. Credits are administrator-authored attribution and drive no
economics; no funds, custody, or external calls are involved. Events are 67
to 267 (add, with the display name) and 64 (remove) BCS bytes.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 22/22 tests with no warnings, and both modules report 100.00%
coverage. Tests cover the published/shared lifecycle with distinct senders,
foreign caps on add and remove, the role-count rule, the capacity boundary
and its precedence over duplicates, duplicate and identical re-credits,
uncredited and absent-record removals, record removal and re-creation,
removal order, role BCS indices, and exact event sizes.
