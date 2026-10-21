# Security review — `composition_title`

Pre-publication qualification, 2026-10-20. This package is unpublished: there
is no `Published.toml`. See `Move.toml`, `README.md`, and the tests for the
current API.

## Reviewed surface

One module with four public functions: `set_title`, `clear_title`, and the
permissionless views `has_title` and `title`. The stored value is one
`String` dynamic field under the module-owned `ExtensionKey()`, added by the
first write and removed by clear, so the field exists exactly when a title is
attached.

## Dependency provenance

`Move.toml` pins `miso_music` at `aae43b34a5b6fe97201ecdb5e9c520cebfc79450`.

## Threat model

Set and clear go through `Composition::uid_mut`, which matches the cap's
`CompositionShare` to the composition's; a cap for another composition does
not type-check. `set_title` validates emptiness (`EEmptyTitle`, 1) and the
300-byte bound (`ETitleTooLong`, 2) before authorization; `clear_title`
authorizes before checking existence. `ExtensionKey` can be constructed only
inside the module, so no other extension can collide with this field. The cap
holder has permanent authority over the composition's dynamic fields. The
value is descriptive: no funds, custody, or external calls are involved.

Events carry the composition id and, on set, the attached value (at most 334
BCS bytes). Equal sets, absent clears, and views emit nothing, so every event
is a transition.

## Evidence

With Sui 1.82.1, `sui move test --coverage --lint --warnings-are-errors`
passes 24/24 tests with no warnings and 100.00% coverage. Tests cover set
before and after publication on a shared object with distinct senders,
per-composition isolation, an unrelated dynamic field left untouched,
empty and 301-byte values on add and replace, exactly 300 bytes in ASCII and
three-byte UTF-8, verbatim storage, absence and clearing, silent views,
absent clears and equal sets, and exact event BCS sizes.
