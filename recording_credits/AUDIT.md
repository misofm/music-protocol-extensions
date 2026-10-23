# Security Audit — `recording_credits`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: modules `recording_credits` and `recording_party_role`, against `miso_music` `1538d77`, `miso_party` `8e59a81` and `credit` `a5ad1f6` as pinned in `Move.toml`. Later commits only apply naming and ordering standards; line references are to the current code.

## What it does

It stores performance and production credits on a `Recording`, together with primary-artist and featured-artist designations. Everything lives in one `RecordingCredits` record under `ExtensionKey()`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of `RecordingAdminCap<RecordingShare>`. Core claims one recording per share type (`miso_music` `recording.move:77`) and one cap per recording (`:131`). `uid_mut` (`:113`) authorizes by type, so a foreign cap fails to type-check.
- **Reader:** anyone.
- **What nobody else can do:** no other package can construct `ExtensionKey` or reach the record's private fields.
- **What nobody can do:** revoke the cap or delete the recording.

## Findings

**RC-1 · Info · Accepted. Credits are admin claims.** `add_credit` (`recording_credits.move:123-153`) accepts any shared `&Party` without that party's consent. It also accepts a free-text `display_name` that is unrelated to `Party::name`. Credits drive no economics.

**RC-2 · Info · Open. A role's level and the billing designations are independent.**
- `RecordingPartyRoleLevel` includes `Primary` and `Featured` (`recording_party_role.move:61,63`).
- These levels have no connection to `primary_artist_ids` or `featured_artist_ids` (`recording_credits.move:180-244`).
- So a party can be designated primary while its roles carry the `Featured` level, and the reverse.
- Consumers should treat the designation sets as authoritative for billing.

**RC-3 · Info · Open. The worst-case record is about 76% of the object size limit.**
- A probe filled every bound at once: 150 credits, each with a 200-byte display name and ten instrumentalist roles that each have a 100-byte instrument name and a level, plus 20 primary and 50 featured designations. The resulting record serialized to 193,494 BCS bytes.
- The object limit is 256,000 bytes, so the current bounds fit.
- Every mutation rewrites the whole record, so storage gas grows with its size.
- Raising any bound needs this size check redone.

## Checked, no finding

- **Authorization:**
  - `add_credit` checks the role count (`:129`, at most 10) before `uid_mut` (`:135`).
  - Every other write authorizes first (`:161`, `:186`, `:205`, `:219`, `:238`).
- **Invariants:**
  - At most one credit per party (`:149`).
  - Bounds: 150 credits (`:148`), 20 primary (`:188`) and 50 featured (`:221`), each with capacity checked before membership.
  - Only credited parties can be designated (`:191`, `:224`).
  - The primary and featured sets are disjoint (`:192`, `:225`).
  - `credit::new` guarantees at least one role and no duplicates.
  - `new_instrumentalist_role` bounds the instrument name to 1 to 100 bytes (`recording_party_role.move:129-130`).
- **Cascade:** `remove_credit` clears any designation and emits that removal before `RecordingCreditRemovedEvent` (`:164-177`). The stream therefore never shows a designated party that has no credit. The last removal drops the record (`:173-175`). Leftover designations are impossible because each one requires a credit.
- **Events:** each mutation emits one event, except the cascade above. `RecordingCreditAddedEvent` carries the full stored credit. The probe matched the README's maximum of 1,307 bytes (64 + 202 + 1 + 1,040). The designation events are 64 bytes.
- **Limits:** a probe ran 150 credits and 70 designations in one scenario without error. That is 220 events, well under the 1,024 limit.
- **Money:** none.

## Operational requirements

- Credit events can come before `RecordingPublishedEvent` within the recording's creation transaction.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 47/47 passed, no warnings.
- `sui move coverage summary`: 100.00% for both modules.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
