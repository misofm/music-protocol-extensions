# Security Audit — `release_description`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `release_description`, against `miso_music` `1538d77` as pinned in `Move.toml`. Later commits only apply naming and ordering standards; line references are to the current code.

## What it does

It stores a release's free-text description, up to 8,192 bytes, as one `String` under `ExtensionKey()`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of the release's `ReleaseAdminCap`. `Release::uid_mut` aborts with `release::EUnauthorized` (0) for a cap of another release (`miso_music` `release.move:150-151,189-190`).
- **Reader:** anyone.
- **What nobody else can do:** no other package can construct `ExtensionKey`.

## Findings

None.

## Checked, no finding

- **Authorization:** `set_description` validates first. It rejects an empty description (`release_description.move:52`) and one over 8,192 bytes (`:53`), then calls `uid_mut` (`:56`). `clear_description` authorizes before checking whether a description exists (`:69-70`).
- **Bound:** the limit counts bytes, not characters. The tests cover it with ASCII and with four-byte UTF-8.
- **PTB argument size:** the largest value, 8,194 BCS bytes, fits within Sui's 16 KiB per-argument limit.
- **Events:**
  - An equal set is silent (`:59`).
  - A clear of an absent description is silent (`:70`).
  - The set event is 34 to 8,226 BCS bytes. The clear event is 32 bytes.
- **Lifecycle and money:** the field exists exactly when a description is attached. No objects or coins are involved.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 20/20 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
