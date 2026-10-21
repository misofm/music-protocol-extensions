// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// Writing credits for a composition: one `Credit<CompositionPartyRole>` per
/// credited `Party`, kept in a single record stored as a dynamic field on the
/// composition's UID and written through its cap-gated `uid_mut`. The record
/// exists exactly while at least one credit is held. Credits are display
/// metadata and are not read by the economics.
module composition_credits::composition_credits;

// === Imports ===

use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use credit::credit::Credit;
use musicos::composition::{Composition, CompositionAdminCap};
use partyos::party::Party;
use composition_credits::composition_party_role::CompositionPartyRole;

// === Errors ===

/// Composition already holds `MAX_CREDITS` credits.
const EMaxCreditsExceeded: u64 = 0;
/// Party already has a credit on this composition.
const EDuplicateParty: u64 = 1;
/// No credits record is attached to this composition.
const ENoCredits: u64 = 2;
/// Party is not credited on the composition.
const EPartyNotFound: u64 = 3;

// === Constants ===

/// Maximum number of credits allowed on a composition.
const MAX_CREDITS: u64 = 50;

// === Structs ===

/// The per-composition attribution record, stored under `ExtensionKey()`.
public struct CompositionCredits has store {
    /// Party ID to credit (display name + roles), in insertion order.
    credits: VecMap<ID, Credit<CompositionPartyRole>>,
}

/// Dynamic-field key: one canonical credits record per composition.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when a party is credited, with the roles as stored.
public struct CompositionCreditAddedEvent has copy, drop {
    composition_id: ID,
    party_id: ID,
    roles: vector<CompositionPartyRole>,
}

/// Emitted when a party's credit is removed.
public struct CompositionCreditRemovedEvent has copy, drop {
    composition_id: ID,
    party_id: ID,
}

// === Public Functions ===

/// Credits a party, creating the record on first use. A party holds at most
/// one credit. At capacity, even a duplicate party aborts `EMaxCreditsExceeded`.
public fun add_credit<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    party: &Party,
    credit: Credit<CompositionPartyRole>,
) {
    let composition_id = object::id(self);
    let party_id = object::id(party);
    let roles = *credit.roles();
    let uid = self.uid_mut(cap);
    if (!df::exists(uid, ExtensionKey())) {
        df::add(uid, ExtensionKey(), CompositionCredits { credits: vec_map::empty() });
    };
    let record: &mut CompositionCredits = df::borrow_mut(uid, ExtensionKey());
    assert!(record.credits.length() < MAX_CREDITS, EMaxCreditsExceeded);
    assert!(!record.credits.contains(&party_id), EDuplicateParty);
    record.credits.insert(party_id, credit);

    emit(CompositionCreditAddedEvent { composition_id, party_id, roles });
}

/// Removes a party's credit, detaching the record when it was the last one.
public fun remove_credit<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    party_id: ID,
) {
    let composition_id = object::id(self);
    let uid = self.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey()), ENoCredits);
    let record: &mut CompositionCredits = df::borrow_mut(uid, ExtensionKey());
    assert!(record.credits.contains(&party_id), EPartyNotFound);
    record.credits.remove(&party_id);
    if (record.credits.is_empty()) {
        let CompositionCredits { credits } = df::remove(uid, ExtensionKey());
        credits.destroy_empty();
    };

    emit(CompositionCreditRemovedEvent { composition_id, party_id });
}

// === View Functions ===

/// Whether at least one credit is attached to this composition.
public fun has_credits<CompositionShare>(self: &Composition<CompositionShare>): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The party-to-credit map. Aborts `ENoCredits` when none is attached.
public fun credits<CompositionShare>(
    self: &Composition<CompositionShare>,
): &VecMap<ID, Credit<CompositionPartyRole>> {
    assert!(df::exists(self.uid(), ExtensionKey()), ENoCredits);
    let record: &CompositionCredits = df::borrow(self.uid(), ExtensionKey());
    &record.credits
}

// === Test Functions ===

#[test_only]
public fun composition_credit_added_fields(
    e: &CompositionCreditAddedEvent,
): (ID, ID, vector<CompositionPartyRole>) {
    (e.composition_id, e.party_id, e.roles)
}

#[test_only]
public fun composition_credit_removed_fields(e: &CompositionCreditRemovedEvent): (ID, ID) {
    (e.composition_id, e.party_id)
}
