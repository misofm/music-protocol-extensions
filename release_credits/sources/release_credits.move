// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// Top-line billing for a release: one `Credit<ReleasePartyRole>` per
/// credited `Party`, kept in a single record stored as a dynamic field on the
/// release's UID and written through its cap-gated `uid_mut`. The record exists
/// exactly while at least one credit is held. Credits are display metadata and
/// are not read by the economics.
///
/// A release credit carries exactly one role: a party is billed as either a
/// `Primary` or a `Featured` artist on the release.
module release_credits::release_credits;

// === Imports ===

use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use credit::credit::Credit;
use musicos::release::{Release, ReleaseAdminCap};
use partyos::party::Party;
use release_credits::release_party_role::ReleasePartyRole;

// === Errors ===

/// Release already holds `MAX_CREDITS` credits.
const EMaxCreditsExceeded: u64 = 0;
/// Party already has a credit on this release.
const EDuplicateParty: u64 = 1;
/// No credits record is attached to this release.
const ENoCredits: u64 = 2;
/// Party is not credited on the release.
const EPartyNotFound: u64 = 3;
/// A release credit must carry exactly one role.
const EInvalidCreditRoleCount: u64 = 4;

// === Constants ===

/// Number of roles a release credit must carry: Primary or Featured.
const CREDIT_ROLE_COUNT: u64 = 1;
/// Maximum number of credits allowed on a release.
const MAX_CREDITS: u64 = 50;

// === Structs ===

/// The per-release attribution record, stored under `ExtensionKey()`.
public struct ReleaseCredits has store {
    /// Party ID to credit (display name + role), in insertion order.
    credits: VecMap<ID, Credit<ReleasePartyRole>>,
}

/// Dynamic-field key: one canonical credits record per release.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when a party is credited, with its one role.
public struct ReleaseCreditAddedEvent has copy, drop {
    release_id: ID,
    party_id: ID,
    role: ReleasePartyRole,
}

/// Emitted when a party's credit is removed.
public struct ReleaseCreditRemovedEvent has copy, drop {
    release_id: ID,
    party_id: ID,
}

// === Public Functions ===

/// Credits a party, creating the record on first use. A credit carries exactly
/// one role and a party holds at most one credit. At capacity, even a duplicate
/// party aborts `EMaxCreditsExceeded`.
public fun add_credit(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    party: &Party,
    credit: Credit<ReleasePartyRole>,
) {
    assert!(credit.roles().length() == CREDIT_ROLE_COUNT, EInvalidCreditRoleCount);

    let release_id = object::id(self);
    let party_id = object::id(party);
    let role = credit.roles()[0];
    let uid = self.uid_mut(cap);
    if (!df::exists(uid, ExtensionKey())) {
        df::add(uid, ExtensionKey(), ReleaseCredits { credits: vec_map::empty() });
    };
    let record: &mut ReleaseCredits = df::borrow_mut(uid, ExtensionKey());
    assert!(record.credits.length() < MAX_CREDITS, EMaxCreditsExceeded);
    assert!(!record.credits.contains(&party_id), EDuplicateParty);
    record.credits.insert(party_id, credit);

    emit(ReleaseCreditAddedEvent { release_id, party_id, role });
}

/// Removes a party's credit, detaching the record when it was the last one.
public fun remove_credit(self: &mut Release, cap: &ReleaseAdminCap, party_id: ID) {
    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey()), ENoCredits);
    let record: &mut ReleaseCredits = df::borrow_mut(uid, ExtensionKey());
    assert!(record.credits.contains(&party_id), EPartyNotFound);
    record.credits.remove(&party_id);
    if (record.credits.is_empty()) {
        let ReleaseCredits { credits } = df::remove(uid, ExtensionKey());
        credits.destroy_empty();
    };

    emit(ReleaseCreditRemovedEvent { release_id, party_id });
}

// === View Functions ===

/// Whether at least one credit is attached to this release.
public fun has_credits(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The party-to-credit map. Aborts `ENoCredits` when none is attached.
public fun credits(self: &Release): &VecMap<ID, Credit<ReleasePartyRole>> {
    assert!(has_credits(self), ENoCredits);
    let record: &ReleaseCredits = df::borrow(self.uid(), ExtensionKey());
    &record.credits
}

// === Test Functions ===

#[test_only]
public fun release_credit_added_fields(e: &ReleaseCreditAddedEvent): (ID, ID, ReleasePartyRole) {
    (e.release_id, e.party_id, e.role)
}

#[test_only]
public fun release_credit_removed_fields(e: &ReleaseCreditRemovedEvent): (ID, ID) {
    (e.release_id, e.party_id)
}
