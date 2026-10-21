# `release_credits`

Top-line billing for a `musicos::release::Release`: one
`Credit<ReleasePartyRole>` (display name plus exactly one role, `Primary` or
`Featured`) per credited `partyos` `Party`, kept in a single `ReleaseCredits`
record stored as a dynamic field on the release and written through its
cap-gated `uid_mut`. Attribution is display-oriented and varies across
platforms, so it lives here rather than in immutable core; it is not read by
any economics, and because it is an extension, other parties may publish
their own credits standard against the same `Release`.

## What it stores

- Key: `ExtensionKey()` — a unit struct local to this package.
- Value: one `ReleaseCredits { credits: VecMap<ID, Credit<ReleasePartyRole>> }`,
  party ID to credit in insertion order. The record is created on the first
  `add_credit` and removed with the last `remove_credit`, so `has_credits`
  is true exactly when at least one credit is held.

Invariants enforced on write: a credit carries exactly one role
(`CREDIT_ROLE_COUNT`), a party holds at most one credit, and a release holds
at most 50 credits (`MAX_CREDITS`). `release_party_role` is a closed enum
with no level axis; a role is read from its BCS variant index.

## API

Writes require the release's `&ReleaseAdminCap` and go through
`release::uid_mut(cap)`, which checks that the cap's `release_id` matches the
release. Views are permissionless. Guard order is argument validation, then
the cap, then stored state.

| Function | Description | Aborts |
|---|---|---|
| `add_credit(rel, cap, party, credit)` | Credits a party, creating the record on first use | `EInvalidCreditRoleCount` (4), `release::EUnauthorized`, `EMaxCreditsExceeded` (0), `EDuplicateParty` (1) |
| `remove_credit(rel, cap, party_id)` | Removes a party's credit; removing the last one detaches the record | `release::EUnauthorized`, `ENoCredits` (2), `EPartyNotFound` (3) |
| `has_credits(rel)` | Whether at least one credit is attached | none |
| `credits(rel)` | The `&VecMap<ID, Credit<ReleasePartyRole>>` | `ENoCredits` (2) when absent |
| `release_party_role::new_primary_role()`, `new_featured_role()` | Role constructors | none |

At capacity, a duplicate party reports `EMaxCreditsExceeded` rather than
`EDuplicateParty`. No write is a silent no-op: re-crediting a party
(even with an identical credit) and removing an uncredited party both abort.

## Events

Both events are monomorphic and carry what an event-only indexer would
otherwise have to look up: the target, the party that keys the entry, and —
on add — the role exactly as stored.

| Event | Fields | BCS bytes |
|---|---|---|
| `ReleaseCreditAddedEvent` | `release_id: ID`, `party_id: ID`, `role: ReleasePartyRole` | 65 |
| `ReleaseCreditRemovedEvent` | `release_id: ID`, `party_id: ID` | 64 |

`role` is the credit's one role; `ReleasePartyRole` is a unit variant
(`Primary = 0`, `Featured = 1` by declaration order), so every add event is
exactly 65 bytes. The display name stays in storage (it normally
duplicates the party's own name from `partyos` events); the events do not
carry the admin cap (derived from the release), counts or indices (replayable
from the ordered add/remove stream), or presence flags.

## Errors

| Code | Constant | Condition |
|---|---|---|
| 0 | `EMaxCreditsExceeded` | Fifty credits already held |
| 1 | `EDuplicateParty` | Party already credited |
| 2 | `ENoCredits` | No record attached |
| 3 | `EPartyNotFound` | Party not credited |
| 4 | `EInvalidCreditRoleCount` | Credit does not carry exactly one role |

## Dependencies

- [`musicos`](https://github.com/misofm/musicos) at
  `24570431c1c02118c2b558d4ac1c30b39ca4cb2f` — `Release` and
  `ReleaseAdminCap`.
- [`partyos`](https://github.com/misofm/partyos) at
  `88c2e40353dbee8d8f98272069b4d836b02b12ae` — `Party`, the credited identity.
- [`credit`](https://github.com/misofm/credit) at
  `6c295ea10f796edfec18f54783733a35210f4b06` — the generic `Credit<Role>`.

## Publishing

Every change is published as a fresh, immutable package identity; nothing is
upgraded in place. `Published.toml` records the prior generation.

## Build and test

```sh
sui move build --lint --warnings-are-errors
sui move build --lint --warnings-are-errors --build-env mainnet
sui move test --coverage --lint --warnings-are-errors
sui move coverage summary
sui move test --build-env mainnet
```
