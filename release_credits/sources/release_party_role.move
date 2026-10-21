// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// Consumers read a role by its BCS variant index: `Primary = 0`, `Featured = 1`.
module release_credits::release_party_role;

// === Enums ===

public enum ReleasePartyRole has copy, drop, store {
    /// A primary (headline) artist on the release.
    Primary,
    /// A featured (guest) artist on the release.
    Featured,
}

// === Public Functions ===

public fun new_primary_role(): ReleasePartyRole {
    ReleasePartyRole::Primary
}

public fun new_featured_role(): ReleasePartyRole {
    ReleasePartyRole::Featured
}
