# Security Audit — `composition_title`

Audited at `61de12cb5a422fde0159f3f80bdee5423e4bb1d3` (2026-10-21). Scope: module `composition_title`, against `miso_music` `1538d77` as pinned in `Move.toml`. The package is unpublished and has no `Published.toml`.

## What it does

It stores a composition's preferred title as one `String` under `ExtensionKey()`. See [README.md](README.md).

## Trust model

- **Writer:** the holder of `CompositionAdminCap<CompositionShare>`. Core claims one composition per share type and one cap per composition (`miso_music` `composition.move:77,120`). `uid_mut` (`:106`) authorizes by type. A compile-failure probe confirmed that a cap of another share type is rejected at type-check.
- **Reader:** anyone.
- **What nobody else can do:** no other package can construct `ExtensionKey`, so none can touch the title.
- **What nobody can do:** revoke the cap or delete the composition.

## Findings

None.

## Checked, no finding

- **Authorization:**
  - `set_title` validates first: it rejects an empty title (`composition_title.move:46`) and a title over 300 bytes (`:47`), then calls `uid_mut` (`:50`).
  - `clear_title` authorizes (`:66`) before it checks whether a title exists (`:67`).
- **Bound:** the limit counts bytes, not characters, so a title of three-byte UTF-8 characters fits 100 of them. The tests cover exactly 300 bytes and 301 bytes.
- **Value:** the title is stored verbatim and nothing on-chain reads it.
- **Events:**
  - An equal set returns before writing or emitting (`:53`).
  - A clear of an absent title is silent (`:67`).
  - `CompositionTitleSetEvent` carries the subject and the title, at most 334 BCS bytes.
  - `CompositionTitleClearedEvent` carries the subject (32 bytes).
- **Lifecycle:** the field exists exactly when a title is attached. No objects are created and no money is involved.

## Operational requirements

- A title can be set in the composition's creation transaction, before `publish`. Indexers must accept that ordering.

## Verification

- Sui 1.82.1.
- `sui move test --coverage --lint --warnings-are-errors`: 24/24 passed, no warnings.
- `sui move coverage summary`: 100.00%.
- Mainnet and testnet builds with `--lint --warnings-are-errors`: pass.
