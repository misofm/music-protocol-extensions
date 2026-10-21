// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// Top-line billing. The record exists exactly while at least one credit is held. Credits are
/// display metadata and are not read by the economics. A credit carries exactly one role, so a
/// party is billed as either a `Primary` or a `Featured` artist.
module release_credits::release_credits;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use credit::credit::Credit;
use miso_music::release::{Release, ReleaseAdminCap};
use miso_party::party::Party;
use release_credits::release_party_role::ReleasePartyRole;

// === Errors ===

const EMaxCreditsExceeded: u64 = 0;
const EDuplicateParty: u64 = 1;
const ENoCredits: u64 = 2;
const EPartyNotFound: u64 = 3;
const EInvalidCreditRoleCount: u64 = 4;

// === Constants ===

const CREDIT_ROLE_COUNT: u64 = 1;
const MAX_CREDITS: u64 = 50;

// === Structs ===

public struct ReleaseCredits has store {
    /// Keyed by party ID, in insertion order.
    credits: VecMap<ID, Credit<ReleasePartyRole>>,
}

public struct ExtensionKey() has copy, drop, store;

// === Events ===

public struct ReleaseCreditAddedEvent has copy, drop {
    release_id: ID,
    party_id: ID,
    display_name: String,
    role: ReleasePartyRole,
}

public struct ReleaseCreditRemovedEvent has copy, drop {
    release_id: ID,
    party_id: ID,
}

// === Public Functions ===

/// At capacity, even a duplicate party aborts `EMaxCreditsExceeded`.
public fun add_credit(
    self: &mut Release,
    cap: &ReleaseAdminCap,
    party: &Party,
    credit: Credit<ReleasePartyRole>,
) {
    assert!(credit.roles().length() == CREDIT_ROLE_COUNT, EInvalidCreditRoleCount);

    let release_id = object::id(self);
    let party_id = object::id(party);
    let display_name = *credit.display_name();
    let role = credit.roles()[0];
    let uid = self.uid_mut(cap);
    if (!df::exists(uid, ExtensionKey())) {
        df::add(uid, ExtensionKey(), ReleaseCredits { credits: vec_map::empty() });
    };
    let record: &mut ReleaseCredits = df::borrow_mut(uid, ExtensionKey());
    assert!(record.credits.length() < MAX_CREDITS, EMaxCreditsExceeded);
    assert!(!record.credits.contains(&party_id), EDuplicateParty);
    record.credits.insert(party_id, credit);

    emit(ReleaseCreditAddedEvent { release_id, party_id, display_name, role });
}

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

public fun has_credits(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

public fun credits(self: &Release): &VecMap<ID, Credit<ReleasePartyRole>> {
    assert!(has_credits(self), ENoCredits);
    let record: &ReleaseCredits = df::borrow(self.uid(), ExtensionKey());
    &record.credits
}

// === Test Functions ===

#[test_only]
public fun release_credit_added_fields(
    e: &ReleaseCreditAddedEvent,
): (ID, ID, String, ReleasePartyRole) {
    (e.release_id, e.party_id, e.display_name, e.role)
}

#[test_only]
public fun release_credit_removed_fields(e: &ReleaseCreditRemovedEvent): (ID, ID) {
    (e.release_id, e.party_id)
}
