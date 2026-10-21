# Security Audit — `release_title`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `release_title`, against `miso_music` `1538d77` as pinned in `Move.toml`. The package is unpublished and has no `Published.toml`.

## What it does

It stores a release's preferred title as one `String` of at most 300 bytes under `ExtensionKey()`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of the release's `ReleaseAdminCap`. `Release::uid_mut` aborts with `release::EUnauthorized` (0) for a cap of another release (`miso_music` `release.move:150-151,189-190`).
- **Reader:** anyone.
- **What nobody else can do:** no other package can construct `ExtensionKey`.

## Findings

None.

## Checked, no finding

- **Authorization:** `set_title` validates first. It rejects an empty title (`release_title.move:41`) and one over 300 bytes (`:42`), then calls `uid_mut` (`:45`). `clear_title` authorizes before checking whether a title exists (`:58-59`).
- **Bound and value:** the limit counts bytes, not characters. The title is stored verbatim.
- **Events:**
  - An equal set is silent (`:48`).
  - A clear of an absent title is silent (`:59`).
  - The set event is at most 334 BCS bytes. The clear event is 32 bytes.
- **Lifecycle and money:** no objects or coins are involved.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 20/20 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
