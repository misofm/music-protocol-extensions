# Security Audit — `recording_advisory`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `recording_advisory`, against `miso_music` `1538d77` as pinned in `Move.toml`.

## What it does

It stores one `Advisory` value on a `Recording` under `ExtensionKey()`. The value is one of `Explicit`, `NotExplicit` or `Cleaned`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of `RecordingAdminCap<RecordingShare>`. Core claims one recording per share type (`miso_music` `recording.move:77`) and one cap per recording (`:131`). `uid_mut` (`:113`) authorizes by type, so a foreign cap fails to type-check.
- **Reader:** anyone.
- **What nobody else can do:** no other package can construct `ExtensionKey` or an `Advisory` variant except through this module's constructors.
- **What nobody can do:** revoke the cap or delete the recording.

## Findings

None.

## Checked, no finding

- **Authorization:** both writes call `uid_mut` (`recording_advisory.move:53`, `:69`). That includes an equal set and a clear of an absent advisory.
- **Values:** `Advisory` is a closed enum (`:22-26`), so malformed values cannot be stored.
- **Absence:** an absent advisory stays distinct from `NotExplicit`. The `advisory` view aborts with `ENoAdvisory` (`:83`) rather than returning a default.
- **Events:**
  - An equal set is silent (`:56`).
  - A clear of an absent advisory is silent (`:70`).
  - The set event is 33 BCS bytes, with the variant index as its last byte. The clear event is 32 bytes.
- **Limits and money:** the stored value is a single byte. No objects, coins or external calls are involved.

## Operational requirements

- Advisory events can come before `RecordingPublishedEvent` within the recording's creation transaction. Indexers must accept that ordering.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 13/13 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
