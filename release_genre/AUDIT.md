# Security Audit — `release_genre`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `release_genre`, against `miso_music` `1538d77` and `genre` `4c47bd1` as pinned in `Move.toml`. Later commits only apply naming and ordering standards; line references are to the current code.

## What it does

It stores an ordered `vector<ID>` of `genre::Genre` IDs on a `Release` under `ExtensionKey()`. The first entry is the primary genre. See [README.md](README.md).

## Trust model

- **Writer:** the holder of the release's `ReleaseAdminCap`. `Release::uid_mut` aborts with `release::EUnauthorized` (0) for a cap of another release (`miso_music` `release.move:150-151,189-190`).
- **Reader:** anyone.
- **Genres:** anyone can create a `Genre`. Each one is frozen and unique by name.
- **What nobody else can do:** no other package can construct `ExtensionKey`.

## Findings

None.

## Checked, no finding

- **Authorization:** all three writes call `uid_mut` (`release_genre.move:60`, `:74`, `:88`) before reading stored state. The tests cover a foreign cap on every write, both with the record present and absent.
- **Genre IDs:** `add_genre` takes a `&Genre` (`:57`), so only an existing `Genre` can enter the list.
- **List invariants:**
  - No duplicates (`:63`).
  - At most six entries (`:64`).
  - Never empty: the last removal drops the field (`:80-82`), and `genres` aborts on absence (`:51`).
- **Events:** the add and remove events are 64 bytes and the clear event is 32 bytes. Replaying them in order reproduces the list. A clear of an absent list is silent (`:89`).
- **Limits and money:** the record is at most 193 bytes. No objects or coins are involved.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 25/25 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
