# Security Audit — `release_kind`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `release_kind`, against `miso_music` `1538d77` as pinned in `Move.toml`.

## What it does

It stores a free-text release classification, such as "Album" or "EP", as one `String` of at most 32 bytes under `ExtensionKey()`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of the release's `ReleaseAdminCap`. `Release::uid_mut` aborts with `release::EUnauthorized` (0) for a cap of another release (`miso_music` `release.move:150-151,189-190`).
- **Reader:** anyone.
- **What nobody else can do:** no other package can construct `ExtensionKey`.

## Findings

None.

## Checked, no finding

- **Authorization:** `set_kind` validates first. It rejects an empty kind (`release_kind.move:41`) and one over 32 bytes (`:42`), then calls `uid_mut` (`:45`). `clear_kind` authorizes before checking whether a kind exists (`:58-59`).
- **Value:** the kind is stored verbatim and nothing on-chain reads it.
- **Events:**
  - An equal set is silent (`:48`).
  - A clear of an absent kind is silent (`:59`).
  - The set event is at most 65 BCS bytes. The clear event is 32 bytes.
- **Lifecycle and money:** no objects or coins are involved.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 21/21 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
