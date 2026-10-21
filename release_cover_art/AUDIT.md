# Security review — `release_cover_art`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `c5a4a3f78eca20c225ff702750b54da5c754fe4c`,
`cover_art` at `ccc18714c65428ae5715fde06b60a911451e120b`,
`release_track_data` at `a432fdf20da872b22a1d1004ed0c6e1396862e3f`, and, in
test mode only, `ori` at `367ed5fe92a8b62da02c1116537cf08d111e0789`.

## Threat model

All four mutations go through `Release::uid_mut`, which aborts
`release::EUnauthorized` for a cap of another release, including on absent
clears. Track indices are validated against the tracklist before
authorization; the overrides are a `ReleaseTrackData` sized from the release
when the record is first attached, and the tracklist is fixed, so they stay
aligned. `cover_art::new` rejects encrypted blobs, so events carry only
public blob IDs. The record is removed by the clear that leaves neither an
album cover nor any override; that check scans the override slots (at most
1,000) only on the clear path. The module-owned key prevents
cross-extension collisions. No funds, custody, or external calls are
involved. Events are 32 to 105 BCS bytes.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 28/28 tests with no warnings and 100.00% coverage. Tests cover the
published/shared lifecycle with a reader and a stranger, foreign caps on
every mutator (with and without a record attached), override resolution and
fallback, the last valid index, out-of-range and `u64::MAX` indices, the raw
override view, record removal and re-creation, equal-set and absent-clear
silence, and exact event BCS layouts.
