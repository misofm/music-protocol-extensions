# Security Audit — `recording_language`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `recording_language`, against `miso_music` `1538d77` and `language_code` `6154235` as pinned in `Move.toml`.

## What it does

It stores an ordered `vector<LanguageCode>` on a `Recording` under `ExtensionKey()`. An empty list means the recording is instrumental. See [README.md](README.md).

## Trust model

- **Writer:** the holder of `RecordingAdminCap<RecordingShare>`. `uid_mut` (`miso_music` `recording.move:113`) authorizes by type, and the cap is unique to its recording (`:77,131`).
- **Reader:** anyone.
- **Codes:** `LanguageCode::new` accepts only the 184 ISO 639-1 codes, so every stored code is valid.
- **What nobody else can do:** no other package can construct `ExtensionKey`.

## Findings

**RL-1 · Low · Open. The README gives the wrong abort codes.**
- The README's error table and API table list `ENoLanguages` = 1, `EMaxLanguagesExceeded` = 2 and `EDuplicateLanguage` = 3.
- The code defines them as 0, 1 and 2 (`recording_language.move:17-19`).
- Probes confirmed the real codes: an absent read aborts 0, eleven codes abort 1, and a repeated code aborts 2.
- A client that maps abort codes using the README will misreport every one of these errors.
- **Suggested fix:** correct both README tables.

## Checked, no finding

- **Authorization:** both writes call `uid_mut` (`:49`, `:68`). Validation runs first (`:47`, `:90-97`): at most ten codes, then no repeats. So an invalid replacement leaves the stored value untouched.
- **Absence and instrumental:** an absent list and an empty list stay distinct. `languages` aborts on absence (`:84`) rather than returning empty.
- **Order:** order is significant. A reordered list counts as a change and emits an event, as the tests show.
- **Events:**
  - An equal set is silent (`:52`).
  - A clear of an absent list is silent (`:69`).
  - The set event carries the codes as strings, 33 to 63 BCS bytes. The clear event is 32 bytes.
- **Limits and money:** at most ten 2-byte codes are stored. The duplicate check is O(n²) over n ≤ 10. No objects or coins are involved.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 20/20 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
