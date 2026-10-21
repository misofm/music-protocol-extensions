# Security review — `composition_credits`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `aae43b34a5b6fe97201ecdb5e9c520cebfc79450`,
`miso_party` at `7b25b1aa4f41ff16e82315b321736042d0debf57`, and `credit` at
`3d5eef4eb275882acfc48c552fe6aaf3357b14c6`.

## Threat model

The security boundary is attribution integrity. Both mutations go through
`Composition::uid_mut`, which requires the `CompositionAdminCap` of the
composition's share type. The module-owned `ExtensionKey` and private stored
fields prevent cross-extension key or value confusion. Parties are unique and
the credit count is bounded at 50; `credit::new` bounds roles to the six
distinct variants. The record is removed with its last credit, so presence
means at least one credit. Credits are descriptive data only: no funds
movement, custody, or authorization depends on them. An administrator can
name a Party without that Party's consent; that is the documented meaning of
an administrator-authored credit.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 13/13 tests with no warnings, and both modules report 100.00%
coverage. The suite covers the published/shared shape, the capacity boundary
and its precedence over duplicates, duplicate and identical re-credits,
removal order, record removal and re-creation, absent-record aborts, and
exact event fields and BCS sizes.
