// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// Consumers read a role by its BCS variant index, so declaration order is part of the format.
module composition_credits::composition_party_role;

// === Enums ===

public enum CompositionPartyRole has copy, drop, store {
    /// Adapted an existing work into this composition.
    Adapter,
    Arranger,
    Composer,
    Lyricist,
    /// Wrote both music and lyrics of the composition.
    Songwriter,
    Translator,
}

// === Public Functions ===

public fun new_adapter_role(): CompositionPartyRole {
    CompositionPartyRole::Adapter
}

public fun new_arranger_role(): CompositionPartyRole {
    CompositionPartyRole::Arranger
}

public fun new_composer_role(): CompositionPartyRole {
    CompositionPartyRole::Composer
}

public fun new_lyricist_role(): CompositionPartyRole {
    CompositionPartyRole::Lyricist
}

public fun new_songwriter_role(): CompositionPartyRole {
    CompositionPartyRole::Songwriter
}

public fun new_translator_role(): CompositionPartyRole {
    CompositionPartyRole::Translator
}
