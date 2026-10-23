# Security Audit — `release_cover_art`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `release_cover_art`, against `miso_music` `1538d77`, `cover_art` `2065cb4` and `release_track_data` `269a921` as pinned in `Move.toml`. `ori` `367ed5f` is pinned for tests only. Later commits only apply naming and ordering standards; line references are to the current code.

## What it does

It stores an album cover and optional per-track overrides on a `Release`. Both live in one `ReleaseCoverArt` record under `ExtensionKey()`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of the release's `ReleaseAdminCap`. The cap has `key, store` and carries a `release_id`. `Release::uid_mut` aborts with `release::EUnauthorized` (0) when that ID does not match (`miso_music` `release.move:150-151,189-190`).
- **Reader:** anyone.
- **What nobody else can do:** no other package can construct `ExtensionKey`.
- **What nobody can do:** revoke the cap or delete the release.

## Findings

None.

## Checked, no finding

- **Authorization:**
  - All four writes reach `uid_mut`: `set_cover` and `set_track_cover` through `borrow_mut_or_init` (`release_cover_art.move:155`, `:158`), and the two clears directly (`:87`, `:121`). This happens before any stored-state check.
  - Track indices are validated first (`:104`, `:119`).
  - The tests cover a foreign cap on every write, both with and without a record attached.
- **Track alignment:**
  - The overrides are created with `release_track_data::filled` (`:157`), sized from `recording_ids` when the record is first attached.
  - Core fixes `recording_ids` at `release::new` and has no mutator, so the overrides stay aligned.
  - Views check the index against the tracklist (`:63`, `:70`) before borrowing.
- **Values:** `cover_art::new` rejects encrypted blobs. A blob is therefore exactly its `blob_id` plus the `Unencrypted` tag, and the set events carry the complete value.
- **Events:**
  - An equal set is silent (`:79`, `:107`).
  - A clear of an absent value is silent (`:88`, `:90`, `:122`, `:125`).
  - Events are 32 to 105 BCS bytes.
  - Removing the record (`:92-94`, `:127-129`) emits no extra event. Presence can be derived from the replayed slots.
- **Lifecycle:** the record exists exactly when the album cover or at least one override is set. `is_empty` (`:139-147`) scans at most 1,000 slots, and only on the clear paths.
- **Limits:**
  - A probe set every override on a 1,000-track release, each with a still and an animated blob. The override vector serialized to 68,002 bytes, below the 256,000-byte object limit.
  - The same probe emitted 1,001 events (1,000 overrides plus the cover). With 23 more events the transaction reached the 1,024 cap. The 24th aborted with `MEMORY_LIMIT_EXCEEDED`.
- **Money:** none.

## Operational requirements

- On large releases, spread override writes across transactions. A single transaction allows 1,024 events and 1,024 PTB commands, and each `set_track_cover` uses one of each. Creating a 1,000-track release and setting all its overrides in the same transaction is not possible.
- Cover-art events can come before `ReleasePublishedEvent` within the creation transaction.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 28/28 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
