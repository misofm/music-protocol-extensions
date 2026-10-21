# Security review — `composition_lyrics`

Pre-publication qualification, 2026-10-20. See `Move.toml`, `README.md`, and
the tests for the current API.

## Dependency provenance

`Move.toml` pins `miso_music` at `a62de87ff9c24c692ba711855b5acd94c4a6472e` and
`language_code` at `61542357f3d2ff989d120185046def7cf6c8bdcb`.

## Threat model

- Set and clear go through `Composition::uid_mut`, which requires the
  `CompositionAdminCap` of the composition's share type; a cap for another
  composition does not type-check. Absent clears authorize too.
- Each `ExtensionKey(LanguageCode)` names one independent byte vector, and the
  key cannot be constructed outside this module. Replacing or clearing one
  language leaves the others untouched.
- Payloads are non-empty and at most 32,768 stored bytes; both bounds are
  checked before authorization. The bound does not limit decompressed size or
  validate the frame, so client decoders must enforce output and memory limits.
- Set events carry the composition, the two-byte language code, and the
  stored bytes (at most 32,806 BCS bytes); clear events carry the composition
  and language (35). Equal sets and absent clears are silent.
- No funds, custody, or external calls are involved.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 12/12 tests with no warnings and 100.00% coverage. Tests cover the
published/shared lifecycle across senders, independent languages, opaque byte
preservation, empty-payload rejection, the 32,768/32,769-byte boundary on add
and replace, equal-set and absent-clear silence, per-composition isolation,
missing reads, and exact event BCS layouts.
