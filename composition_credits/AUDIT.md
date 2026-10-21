# Security Audit — `composition_credits`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: modules `composition_credits` and `composition_party_role`, against `miso_music` `1538d77`, `miso_party` `8e59a81` and `credit` `a5ad1f6` as pinned in `Move.toml`.

## What it does

It stores songwriting and publishing credits on a `Composition`. Each credited `Party` ID maps to a `Credit<CompositionPartyRole>`, and all of them sit in one `CompositionCredits` record under `ExtensionKey()`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of `CompositionAdminCap<CompositionShare>`. The cap has `key, store`, so it can be transferred or held in a Vault.
- **Why the cap is bound to one composition:** core claims each `Composition<CompositionShare>` from the registry under `CompositionKey<CompositionShare>`, and claims its only cap under `CompositionAdminCapKey` (`miso_music` `composition.move:77,120`). The share type therefore ties one cap to one composition. `uid_mut` (`composition.move:106`) checks nothing at run time. A cap for a different share type fails to type-check, which a compile-failure probe confirmed.
- **Reader:** anyone, through the views.
- **What nobody else can do:** no other package can construct `ExtensionKey`, so none can touch the record, including code that receives `&mut UID` from the same cap.
- **What nobody can do:** revoke the cap, freeze the record, or delete the composition. Core has no delete path, so the record lasts until its last credit is removed.

## Findings

**CC-1 · Info · Accepted. Credits are admin claims, not attestations.** `add_credit` (`composition_credits.move:52-72`) takes any shared `&Party`, whose consent is not needed. It also takes a free-text `display_name` that has no tie to `Party::name`. A credit records what the composition admin asserts. The README describes it that way: attribution is display-oriented and no economics read it.

## Checked, no finding

- **Authorization:** both writes call `uid_mut(cap)` (`:62`, `:80`) before any stored-state check. A Party ID is derived from the `&Party` passed in (`:59`), so only a real `miso_party::Party` can be credited.
- **Bounds:**
  - At most 50 credits (`:26`, `:67`), with capacity checked before duplicates (`:67-68`).
  - One credit per party (`:68`).
  - `credit::new` requires 1 to 50 distinct roles and a display name of 1 to 200 bytes. With six unit variants, a credit holds at most six roles.
- **Lifecycle:** the record is created on the first add (`:63-65`). It is destroyed with the last remove (`:85-88`), using `destroy_empty`. So `has_credits` is true exactly when at least one credit is held. Removing from an absent record aborts `ENoCredits` (`:81`). Removing an unknown party aborts `EPartyNotFound` (`:83`).
- **Events:**
  - `CompositionCreditAddedEvent` carries the subject, the party, the display name and the roles as stored. It is 68 to 273 BCS bytes, as the tests confirm.
  - `CompositionCreditRemovedEvent` carries the subject and the party (64 bytes).
  - No write is silent. Every successful mutation emits exactly one event.
- **Limits:** the largest record is 50 × 241 bytes, about 12 KB, far below the 256,000-byte object limit. `VecMap` scans touch at most 50 entries.
- **Money:** none. No coins, balances or objects are created, wrapped or transferred.

## Operational requirements

- A `Composition` can be written before it is published, inside its creation transaction. Indexers must therefore accept credit events that come before `CompositionPublishedEvent` in the same transaction.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 13/13 passed, no warnings.
- `sui move coverage summary`: 100.00% for both modules.
- `sui move build --build-env mainnet` and `--build-env testnet`, each with `--lint --warnings-are-errors`: pass.
