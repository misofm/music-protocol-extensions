# Security Audit — `composition_lyrics`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `composition_lyrics`, against `miso_music` `1538d77` and `language_code` `6154235` as pinned in `Move.toml`.

## What it does

It stores compressed lyrics on a `Composition`, one `vector<u8>` per ISO 639-1 language, each under its own `ExtensionKey(LanguageCode)` dynamic field. See [README.md](README.md).

## Trust model

- **Writer:** the holder of `CompositionAdminCap<CompositionShare>`. Core claims one composition per share type (`miso_music` `composition.move:77`) and one cap per composition (`:120`). `uid_mut` (`:106`) authorizes by type, so a foreign cap fails to type-check.
- **Reader:** anyone.
- **What nobody else can do:** `ExtensionKey` has no public constructor, so no other package can read, replace or remove an entry.
- **What nobody can do:** revoke the cap or delete the composition.

## Findings

**CL-1 · Low · Open. Payloads over about 16 KiB cannot be passed as a single PTB argument.**
- `set_lyrics` accepts up to `MAX_LYRICS_LENGTH` = 32,768 bytes (`composition_lyrics.move:22,50`).
- Sui caps each pure argument at 16 KiB, BCS-encoded (`max_pure_argument_size`, `sui-protocol-config/src/lib.rs:2823`). That leaves at most 16,381 payload bytes.
- A larger payload can only be built in the PTB: split it into two pure arguments and join them with `0x1::vector::append`, or build it with `MakeMoveVec`.
- Neither README mentions this, so a client that passes the bytes directly will have its transaction rejected for any lyrics between 16,382 and 32,768 bytes.
- The 128 KiB transaction-size cap also limits each transaction to about three full-size entries.
- **Suggested fix:** document the split-and-append pattern, or lower the bound to 16,381.

**CL-2 · Info · Accepted. The payload is opaque.**
- `set_lyrics` checks only that the payload is non-empty and within the size bound (`:49-50`).
- It does not check the zstd frame or the UTF-8 encoding, and it does not limit the decompressed size.
- A 32 KiB frame can decompress to an arbitrarily large output. The README says so and assigns decoder limits to clients.

**CL-3 · Info · Open. The README's "one value under a single `ExtensionKey()`" does not hold for this package.**
- The root `README.md` says this, and so does `CLAUDE.md`.
- This package's key is `ExtensionKey(LanguageCode)` (`:26`). A composition can carry up to 184 independent fields, one per code in `language_code`, which comes to about 6 MB at the bound.
- The package README describes the layout correctly. Only the repository-level statement is inaccurate.

## Checked, no finding

- **Authorization:** both writes call `uid_mut` (`:53`, `:71`). Validation runs before authorization (`:49-50`), so an invalid value reports its own code whatever cap is supplied. A clear of an absent entry still requires the cap.
- **Isolation:** each language's key is independent, so setting or clearing one leaves the others unchanged, as the tests show. Lyrics on one composition never affect another.
- **Event behavior:**
  - An equal set returns before writing or emitting (`:57`).
  - A clear of an absent entry is silent (`:73`).
  - `CompositionLyricsSetEvent` carries the subject, the two-letter code and the stored bytes. It is 37 to 32,806 BCS bytes, below the 250 KiB per-event limit.
  - `CompositionLyricsClearedEvent` carries the subject and the code (35 bytes).
- **Limits:** each entry is its own dynamic-field object of at most about 32.8 KB, so the object size limit is never approached. The 5 MB per-transaction written-object cap is unreachable given the transaction-size cap.
- **Money and lifecycle:** no coins and no new objects are involved. Fields are added and removed in place.

## Operational requirements

- Split any payload over 16,381 bytes across pure arguments and rebuild it on-chain before calling `set_lyrics` (CL-1).
- Bound decoder memory and output, and handle malformed frames (CL-2).
- List attached languages by enumerating the composition's dynamic fields, or by replaying set and clear events per `(composition_id, language)`.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 12/12 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
- CL-1 is derived from the protocol configuration of the pinned Sui framework. It was not exercised on a network.
