# Security Audit — `recording_version`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `recording_version`, against `miso_music` `1538d77` as pinned in `Move.toml`. The package is unpublished and has no `Published.toml`.

## What it does

It stores a recording's version name, such as "Live" or "Radio Edit", as one `String` under `ExtensionKey()`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of `RecordingAdminCap<RecordingShare>`. `uid_mut` (`miso_music` `recording.move:113`) authorizes by type, and the cap is unique to its recording (`:77,131`).
- **Reader:** anyone.
- **What nobody else can do:** no other package can construct `ExtensionKey`.

## Findings

None.

## Checked, no finding

- **Authorization:** `set_version` validates first. It rejects an empty name (`recording_version.move:45`) and a name over 300 bytes (`:46`), then calls `uid_mut` (`:48`). `clear_version` authorizes before checking whether a name exists (`:64-65`).
- **Bound:** the limit counts bytes, not characters. The tests cover a value of exactly 300 bytes in three-byte UTF-8 and a rejected value of 303 bytes.
- **Events:**
  - An equal set is silent (`:51`).
  - A clear of an absent name is silent (`:65`).
  - The set event is 34 to 334 BCS bytes. The clear event is 32 bytes.
- **Lifecycle and money:** the field exists exactly when a name is attached. No objects or coins are involved.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 18/18 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
