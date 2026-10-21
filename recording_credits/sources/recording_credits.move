// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// Credits for a recording: one `Credit<RecordingPartyRole>` per credited
/// `Party` plus primary and featured artist designations, kept in a single
/// record stored as a dynamic field on the recording's UID and written through
/// its cap-gated `uid_mut`. The record exists exactly while at least one credit
/// is held. Credits are display metadata and are not read by the economics.
///
/// The primary and featured sets are disjoint subsets of the credited parties:
/// removing a credit ends any designation the party held.
module recording_credits::recording_credits;

// === Imports ===

use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_map::{Self, VecMap};
use sui::vec_set::{Self, VecSet};
use credit::credit::Credit;
use musicos::recording::{Recording, RecordingAdminCap};
use partyos::party::Party;
use recording_credits::recording_party_role::RecordingPartyRole;

// === Errors ===

/// Credit has more than `MAX_ROLES_PER_CREDIT` roles.
const EMaxRolesExceeded: u64 = 0;
/// Recording already holds `MAX_CREDITS` credits.
const EMaxCreditsExceeded: u64 = 1;
/// Recording already has `MAX_PRIMARY_ARTISTS` primary artists.
const EMaxPrimaryArtistsExceeded: u64 = 2;
/// Recording already has `MAX_FEATURED_ARTISTS` featured artists.
const EMaxFeaturedArtistsExceeded: u64 = 3;
/// Party already has a credit on this recording.
const EDuplicateParty: u64 = 4;
/// Party is already a primary artist.
const EAlreadyPrimaryArtist: u64 = 5;
/// Party is already a featured artist.
const EAlreadyFeaturedArtist: u64 = 6;
/// No credits record is attached to this recording.
const ENoCredits: u64 = 7;
/// Party is not credited on the recording.
const EPartyNotFound: u64 = 8;
/// Credited party is not a primary artist.
const ENotPrimaryArtist: u64 = 9;
/// Credited party is not a featured artist.
const ENotFeaturedArtist: u64 = 10;

// === Constants ===

/// Maximum number of roles a credit can have.
const MAX_ROLES_PER_CREDIT: u64 = 10;
/// Maximum number of credits allowed on a recording.
const MAX_CREDITS: u64 = 150;
/// Maximum number of primary artists allowed on a recording.
const MAX_PRIMARY_ARTISTS: u64 = 20;
/// Maximum number of featured artists allowed on a recording.
const MAX_FEATURED_ARTISTS: u64 = 50;

// === Structs ===

/// The per-recording attribution record, stored under `ExtensionKey()`.
public struct RecordingCredits has store {
    /// Party ID to credit (display name + roles), in insertion order.
    credits: VecMap<ID, Credit<RecordingPartyRole>>,
    /// IDs of the primary artists. Always a subset of `credits`.
    primary_artist_ids: VecSet<ID>,
    /// IDs of the featured artists. Always a subset of `credits`.
    featured_artist_ids: VecSet<ID>,
}

/// Dynamic-field key: one canonical credits record per recording.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when a party is credited, with the roles as stored (instrument
/// names and levels included); the display name stays in storage.
public struct RecordingCreditAddedEvent has copy, drop {
    recording_id: ID,
    party_id: ID,
    roles: vector<RecordingPartyRole>,
}

/// Emitted when a party's credit is removed, after the artist-removed event
/// for any designation the party held.
public struct RecordingCreditRemovedEvent has copy, drop {
    recording_id: ID,
    party_id: ID,
}

/// Emitted when a credited party is designated a primary artist.
public struct RecordingPrimaryArtistAddedEvent has copy, drop {
    recording_id: ID,
    party_id: ID,
}

/// Emitted when a primary artist is un-designated, explicitly or because
/// their credit is removed (then before `RecordingCreditRemovedEvent`).
public struct RecordingPrimaryArtistRemovedEvent has copy, drop {
    recording_id: ID,
    party_id: ID,
}

/// Emitted when a credited party is designated a featured artist.
public struct RecordingFeaturedArtistAddedEvent has copy, drop {
    recording_id: ID,
    party_id: ID,
}

/// Emitted when a featured artist is un-designated, explicitly or because
/// their credit is removed (then before `RecordingCreditRemovedEvent`).
public struct RecordingFeaturedArtistRemovedEvent has copy, drop {
    recording_id: ID,
    party_id: ID,
}

// === Public Functions ===

/// Credits a party, creating the record on first use. A credit carries 1-10
/// roles and a party holds at most one credit. At capacity, even a duplicate
/// party aborts `EMaxCreditsExceeded`.
public fun add_credit<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party: &Party,
    credit: Credit<RecordingPartyRole>,
) {
    assert!(credit.roles().length() <= MAX_ROLES_PER_CREDIT, EMaxRolesExceeded);

    let recording_id = object::id(self);
    let party_id = object::id(party);
    let roles = *credit.roles();
    let uid = self.uid_mut(cap);
    if (!df::exists(uid, ExtensionKey())) {
        df::add(
            uid,
            ExtensionKey(),
            RecordingCredits {
                credits: vec_map::empty(),
                primary_artist_ids: vec_set::empty(),
                featured_artist_ids: vec_set::empty(),
            },
        );
    };
    let record: &mut RecordingCredits = df::borrow_mut(uid, ExtensionKey());
    assert!(record.credits.length() < MAX_CREDITS, EMaxCreditsExceeded);
    assert!(!record.credits.contains(&party_id), EDuplicateParty);
    record.credits.insert(party_id, credit);

    emit(RecordingCreditAddedEvent { recording_id, party_id, roles });
}

/// Removes a party's credit and any designation it held. A cleared designation
/// emits its artist-removed event before the credit-removed event. Removing the
/// last credit detaches the record.
public fun remove_credit<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party_id: ID,
) {
    let recording_id = object::id(self);
    let uid = self.uid_mut(cap);
    let record = borrow_mut(uid);
    assert!(record.credits.contains(&party_id), EPartyNotFound);
    if (record.primary_artist_ids.contains(&party_id)) {
        record.primary_artist_ids.remove(&party_id);
        emit(RecordingPrimaryArtistRemovedEvent { recording_id, party_id });
    };
    if (record.featured_artist_ids.contains(&party_id)) {
        record.featured_artist_ids.remove(&party_id);
        emit(RecordingFeaturedArtistRemovedEvent { recording_id, party_id });
    };
    record.credits.remove(&party_id);
    if (record.credits.is_empty()) {
        let RecordingCredits { .. } = df::remove(uid, ExtensionKey());
    };

    emit(RecordingCreditRemovedEvent { recording_id, party_id });
}

/// Designates a credited party as a primary artist. Aborts if the primary set
/// is full, the party is uncredited, or it is already primary or featured.
public fun add_primary_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party_id: ID,
) {
    let recording_id = object::id(self);
    let record = borrow_mut(self.uid_mut(cap));
    assert!(
        record.primary_artist_ids.length() < MAX_PRIMARY_ARTISTS,
        EMaxPrimaryArtistsExceeded,
    );
    assert!(record.credits.contains(&party_id), EPartyNotFound);
    assert!(!record.featured_artist_ids.contains(&party_id), EAlreadyFeaturedArtist);
    assert!(!record.primary_artist_ids.contains(&party_id), EAlreadyPrimaryArtist);
    record.primary_artist_ids.insert(party_id);

    emit(RecordingPrimaryArtistAddedEvent { recording_id, party_id });
}

/// Removes a party's primary designation, leaving the credit intact.
public fun remove_primary_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party_id: ID,
) {
    let recording_id = object::id(self);
    let record = borrow_mut(self.uid_mut(cap));
    assert!(record.credits.contains(&party_id), EPartyNotFound);
    assert!(record.primary_artist_ids.contains(&party_id), ENotPrimaryArtist);
    record.primary_artist_ids.remove(&party_id);

    emit(RecordingPrimaryArtistRemovedEvent { recording_id, party_id });
}

/// Designates a credited party as a featured artist. Aborts if the featured
/// set is full, the party is uncredited, or it is already primary or featured.
public fun add_featured_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party_id: ID,
) {
    let recording_id = object::id(self);
    let record = borrow_mut(self.uid_mut(cap));
    assert!(
        record.featured_artist_ids.length() < MAX_FEATURED_ARTISTS,
        EMaxFeaturedArtistsExceeded,
    );
    assert!(record.credits.contains(&party_id), EPartyNotFound);
    assert!(!record.primary_artist_ids.contains(&party_id), EAlreadyPrimaryArtist);
    assert!(!record.featured_artist_ids.contains(&party_id), EAlreadyFeaturedArtist);
    record.featured_artist_ids.insert(party_id);

    emit(RecordingFeaturedArtistAddedEvent { recording_id, party_id });
}

/// Removes a party's featured designation, leaving the credit intact.
public fun remove_featured_artist<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    party_id: ID,
) {
    let recording_id = object::id(self);
    let record = borrow_mut(self.uid_mut(cap));
    assert!(record.credits.contains(&party_id), EPartyNotFound);
    assert!(record.featured_artist_ids.contains(&party_id), ENotFeaturedArtist);
    record.featured_artist_ids.remove(&party_id);

    emit(RecordingFeaturedArtistRemovedEvent { recording_id, party_id });
}

// === View Functions ===

/// Whether at least one credit is attached to this recording.
public fun has_credits<RecordingShare>(self: &Recording<RecordingShare>): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The party-to-credit map. Aborts `ENoCredits` when none is attached.
public fun credits<RecordingShare>(
    self: &Recording<RecordingShare>,
): &VecMap<ID, Credit<RecordingPartyRole>> {
    &borrow(self.uid()).credits
}

/// The primary-artist IDs. Aborts `ENoCredits` when none is attached.
public fun primary_artist_ids<RecordingShare>(
    self: &Recording<RecordingShare>,
): &VecSet<ID> {
    &borrow(self.uid()).primary_artist_ids
}

/// The featured-artist IDs. Aborts `ENoCredits` when none is attached.
public fun featured_artist_ids<RecordingShare>(
    self: &Recording<RecordingShare>,
): &VecSet<ID> {
    &borrow(self.uid()).featured_artist_ids
}

/// Whether the party is a primary artist (false if no record is attached).
public fun is_primary_artist<RecordingShare>(
    self: &Recording<RecordingShare>,
    party_id: ID,
): bool {
    has_credits(self) && borrow(self.uid()).primary_artist_ids.contains(&party_id)
}

/// Whether the party is a featured artist (false if no record is attached).
public fun is_featured_artist<RecordingShare>(
    self: &Recording<RecordingShare>,
    party_id: ID,
): bool {
    has_credits(self) && borrow(self.uid()).featured_artist_ids.contains(&party_id)
}

// === Private Functions ===

fun borrow(uid: &UID): &RecordingCredits {
    assert!(df::exists(uid, ExtensionKey()), ENoCredits);
    df::borrow(uid, ExtensionKey())
}

fun borrow_mut(uid: &mut UID): &mut RecordingCredits {
    assert!(df::exists(uid, ExtensionKey()), ENoCredits);
    df::borrow_mut(uid, ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun recording_credit_added_fields(
    e: &RecordingCreditAddedEvent,
): (ID, ID, vector<RecordingPartyRole>) {
    (e.recording_id, e.party_id, e.roles)
}

#[test_only]
public fun recording_credit_removed_fields(e: &RecordingCreditRemovedEvent): (ID, ID) {
    (e.recording_id, e.party_id)
}

#[test_only]
public fun recording_primary_artist_added_fields(e: &RecordingPrimaryArtistAddedEvent): (ID, ID) {
    (e.recording_id, e.party_id)
}

#[test_only]
public fun recording_primary_artist_removed_fields(
    e: &RecordingPrimaryArtistRemovedEvent,
): (ID, ID) {
    (e.recording_id, e.party_id)
}

#[test_only]
public fun recording_featured_artist_added_fields(e: &RecordingFeaturedArtistAddedEvent): (ID, ID) {
    (e.recording_id, e.party_id)
}

#[test_only]
public fun recording_featured_artist_removed_fields(
    e: &RecordingFeaturedArtistRemovedEvent,
): (ID, ID) {
    (e.recording_id, e.party_id)
}
