# Security Audit — `recording_genre`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `recording_genre`, against `miso_music` `1538d77` and `genre` `4c47bd1` as pinned in `Move.toml`. Later commits only apply naming and ordering standards; line references are to the current code.

## What it does

It stores an ordered `vector<ID>` of `genre::Genre` IDs on a `Recording` under `ExtensionKey()`. The first entry is the primary genre. See [README.md](README.md).

## Trust model

- **Writer:** the holder of `RecordingAdminCap<RecordingShare>`. `uid_mut` (`miso_music` `recording.move:113`) authorizes by type, and the cap is unique to its recording (`:77,131`).
- **Reader:** anyone.
- **Genres:** anyone can create a `Genre` through `genre::new`. Each one is frozen and derived from its name, so names are unique.
- **What nobody else can do:** no other package can construct `ExtensionKey`.

## Findings

None.

## Checked, no finding

- **Authorization:** all three writes call `uid_mut` (`recording_genre.move:64`, `:82`, `:99`) before reading stored state.
- **Genre IDs:** `add_genre` takes a `&Genre` (`:60`), so only the ID of an existing frozen `Genre` from the pinned package can enter the list. `remove_genre` takes a bare `ID`, but it can only remove.
- **List invariants:**
  - No duplicates (`:67`).
  - At most six entries (`:68`), with duplicates checked before capacity, as documented.
  - Never empty: the last removal drops the field (`:88-90`). `genres` aborts with `ENoGenres` (`:51`) instead of returning an empty list.
- **Events:**
  - The add and remove events are 64 bytes each and carry the genre ID. The clear event is 32 bytes.
  - Replaying them in order reproduces the list, including which genre becomes primary when the first one is removed.
  - A clear of an absent list is silent (`:100`).
- **Limits and money:** the record is at most 193 bytes. No objects or coins are involved.

## Operational requirements

- Resolve genre names from the frozen `Genre` objects or from `GenreCreatedEvent`.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 18/18 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
