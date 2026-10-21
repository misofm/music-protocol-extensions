# Security Audit — `release_credits`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: modules `release_credits` and `release_party_role`, against `miso_music` `1538d77`, `miso_party` `8e59a81` and `credit` `a5ad1f6` as pinned in `Move.toml`.

## What it does

It stores top-line billing on a `Release`: each credited `Party` ID maps to a `Credit<ReleasePartyRole>` with exactly one role, `Primary` or `Featured`. All credits sit in one `ReleaseCredits` record under `ExtensionKey()`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of the release's `ReleaseAdminCap`. `Release::uid_mut` aborts with `release::EUnauthorized` (0) for a cap of another release (`miso_music` `release.move:150-151,189-190`).
- **Reader:** anyone.
- **What nobody else can do:** no other package can construct `ExtensionKey`.

## Findings

**RLC-1 · Info · Accepted. Credits are admin claims.** `add_credit` (`release_credits.move:54-76`) accepts any shared `&Party` without that party's consent. It also accepts a free-text display name that is unrelated to `Party::name`. Billing here drives no economics.

## Checked, no finding

- **Authorization:**
  - `add_credit` checks the role count first (`:60`, exactly one role), then calls `uid_mut` (`:66`).
  - `remove_credit` authorizes first (`:80`).
  - The tests cover a foreign cap on both writes.
- **Invariants:**
  - At most one credit per party (`:72`).
  - At most 50 credits (`:28`, `:71`), with capacity checked before duplicates.
  - The record is destroyed with its last credit (`:85-88`).
  - Indexing `roles()[0]` (`:65`) is safe because of the role-count check.
- **Events:** the added event carries the subject, the party, the display name and the single role, 67 to 267 BCS bytes. The removed event is 64 bytes. Every successful write emits exactly one event.
- **Limits and money:** the largest record is about 12 KB. No objects or coins are involved.

## Operational requirements

- Credit events can come before `ReleasePublishedEvent` within the creation transaction.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 22/22 passed, no warnings.
- `sui move coverage summary`: 100.00% for both modules.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
