# Security review — `recording_language`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `c5a4a3f78eca20c225ff702750b54da5c754fe4c` and
`language_code` at `61542357f3d2ff989d120185046def7cf6c8bdcb`.

## Threat model

Set and clear go through `Recording::uid_mut`, which requires the
`RecordingAdminCap` of the recording's share type, including the equal-set
and absent-clear paths. `LanguageCode` is valid ISO 639-1 by construction;
this package bounds the list at ten codes and rejects repeats, both before
authorization, so an invalid replacement leaves the stored value untouched.
An attached empty list is an explicit instrumental claim and stays distinct
from absence; `languages` aborts `ENoLanguages` (0) rather than defaulting.
The module-owned key prevents cross-extension collisions. No funds, custody,
or external calls are involved. Set events are 33 to 63 BCS bytes; clear
events are 32.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 20/20 tests with no warnings and 100.00% coverage. Tests cover the
published/shared lifecycle with a stranger reader, caller order (a reordered
list is a change and emits), instrumental versus absent, equal-set and
absent-clear silence, the ten-code bound and its precedence over duplicates,
invalid replacements leaving storage intact, per-recording isolation, and
exact event BCS layouts.
