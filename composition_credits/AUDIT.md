# Security review — `composition_credits`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `e676920b70e03cd2de8a52f440374d88d17d063f`,
`miso_party` at `defb05a6066cdf7e8949f9162f00589d38eef6ce`, and `credit` at
`6c295ea10f796edfec18f54783733a35210f4b06`.

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
