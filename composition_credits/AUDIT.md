# Security review — `composition_credits`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `a62de87ff9c24c692ba711855b5acd94c4a6472e`,
`miso_party` at `9374c6eed64c907722ac1c93813c76dc7912b357`, and `credit` at
`5aa56d788657f7438d85ae07862d07ebd3cb5f8c`.

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
