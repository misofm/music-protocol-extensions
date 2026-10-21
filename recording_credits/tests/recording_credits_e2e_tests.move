// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// End-to-end scenarios under `sui::test_scenario`: the `Recording` is
/// published and shared, then re-accessed via `take_shared` in later
/// transactions; the admin writes with the typed cap and a stranger without
/// any capability reads the result back.
#[test_only]
module recording_credits::recording_credits_e2e_tests;

// === Imports ===

use std::unit_test::{assert_eq, destroy};
use sui::event::events_by_type;
use sui::test_scenario::{Self, Scenario};
use credit::credit::{Self, Credit};
use miso_music::composition;
use miso_music::recording::{Self, Recording, RecordingAdminCap};
use miso_party::party::{Self, Party, PartyAdminCap};
use recording_credits::recording_credits as credits;
use recording_credits::recording_party_role::{Self as rpr, RecordingPartyRole};

const ADMIN: address = @0xAD;
const STRANGER: address = @0x51;

public struct TestShare() has drop;

fun vocalist(name: vector<u8>): Credit<RecordingPartyRole> {
    credit::new(name.to_string(), vector[rpr::new_vocalist_role(option::none())])
}

fun producer(name: vector<u8>): Credit<RecordingPartyRole> {
    credit::new(name.to_string(), vector[rpr::new_producer_role(option::none())])
}

fun mk_party(name: vector<u8>, ctx: &mut TxContext): (Party, PartyAdminCap) {
    party::new(party::new_individual_kind(), name.to_string(), ctx)
}

/// Creates and publishes (shares) a recording; the admin cap is carried as a
/// local value across `next_tx` calls.
fun publish_shared_recording(ts: &mut Scenario): RecordingAdminCap<TestShare> {
    let (comp, comp_cap) = composition::new_for_testing<TestShare>(ts.ctx());
    let (rec, cap) = recording::new_for_testing<TestShare>(object::id(&comp), ts.ctx());
    comp.publish(&comp_cap);
    destroy(comp_cap);
    rec.publish(&cap);
    cap
}

/// The flagship path: a recording is published and shared, the admin credits
/// two parties and designates one primary / one featured across a later
/// transaction (asserting the full event payloads emitted along the way),
/// and a stranger holding no capability at all reads the exact same
/// resulting state back in a transaction of their own.
#[test]
fun full_credit_lifecycle_on_published_shared_recording() {
    let mut ts = test_scenario::begin(ADMIN);
    let cap = publish_shared_recording(&mut ts);

    // --- Tx 2 (ADMIN): the recording is now a shared object; take it and
    // run the full write lifecycle against it ---
    ts.next_tx(ADMIN);
    let mut rec = ts.take_shared<Recording<TestShare>>();
    let (lead, lead_cap) = mk_party(b"Lead Party", ts.ctx());
    let (guest, guest_cap) = mk_party(b"Guest Party", ts.ctx());
    let lead_id = object::id(&lead);
    let guest_id = object::id(&guest);
    let recording_id = object::id(&rec);

    let lead_credit = credit::new(
        b"Lead Display".to_string(),
        vector[rpr::new_vocalist_role(option::some(rpr::new_lead_role_level()))],
    );
    let guest_credit = credit::new(
        b"Guest Display".to_string(),
        vector[rpr::new_vocalist_role(option::some(rpr::new_featured_role_level()))],
    );
    credits::add_credit(&mut rec, &cap, &lead, lead_credit);
    credits::add_credit(&mut rec, &cap, &guest, guest_credit);
    credits::add_primary_artist(&mut rec, &cap, object::id(&lead));
    credits::add_featured_artist(&mut rec, &cap, object::id(&guest));

    assert_eq!(credits::credits(&rec).length(), 2);
    assert!(credits::is_primary_artist(&rec, lead_id));
    assert!(credits::is_featured_artist(&rec, guest_id));
    assert!(!credits::is_featured_artist(&rec, lead_id));
    assert!(!credits::is_primary_artist(&rec, guest_id));

    // Full RecordingCreditAddedEvent payloads, not just presence.
    let added = events_by_type<credits::RecordingCreditAddedEvent>();
    assert_eq!(added.length(), 2);
    let (event_object, event_party, event_roles) =
        credits::recording_credit_added_fields(&added[0]);
    assert_eq!(event_object, recording_id);
    assert_eq!(event_party, lead_id);
    assert_eq!(event_roles, *lead_credit.roles());
    let (event_object, event_party, event_roles) =
        credits::recording_credit_added_fields(&added[1]);
    assert_eq!(event_object, recording_id);
    assert_eq!(event_party, guest_id);
    assert_eq!(event_roles, *guest_credit.roles());
    assert_eq!(credits::credits(&rec)[&lead_id], lead_credit);
    assert_eq!(credits::credits(&rec)[&guest_id], guest_credit);

    // Designation payloads. These must be asserted in the same transaction
    // they were emitted in — `test_scenario::next_tx` finalizes the
    // transaction's effects, so `events_by_type` no longer sees them once
    // the scenario moves on.
    let primary_added = events_by_type<credits::RecordingPrimaryArtistAddedEvent>();
    assert_eq!(primary_added.length(), 1);
    let (event_object, event_party) =
        credits::recording_primary_artist_added_fields(&primary_added[0]);
    assert_eq!(event_object, recording_id);
    assert_eq!(event_party, lead_id);
    let featured_added = events_by_type<credits::RecordingFeaturedArtistAddedEvent>();
    assert_eq!(featured_added.length(), 1);
    let (event_object, event_party) =
        credits::recording_featured_artist_added_fields(&featured_added[0]);
    assert_eq!(event_object, recording_id);
    assert_eq!(event_party, guest_id);

    test_scenario::return_shared(rec);

    // --- Tx 3 (STRANGER, holds no capability whatsoever): reads the shared
    // recording back — proving reads are permissionless ---
    ts.next_tx(STRANGER);
    let rec = ts.take_shared<Recording<TestShare>>();
    assert_eq!(credits::credits(&rec).length(), 2);
    assert!(credits::is_primary_artist(&rec, lead_id));
    assert!(credits::is_featured_artist(&rec, guest_id));
    assert!(!credits::is_featured_artist(&rec, lead_id));
    assert!(!credits::is_primary_artist(&rec, guest_id));

    // Read-only views are silent; the new transaction contains no mutation
    // events despite reading every exposed projection.
    assert_eq!(events_by_type<credits::RecordingCreditAddedEvent>().length(), 0);
    assert_eq!(events_by_type<credits::RecordingCreditRemovedEvent>().length(), 0);
    assert_eq!(events_by_type<credits::RecordingPrimaryArtistAddedEvent>().length(), 0);
    assert_eq!(events_by_type<credits::RecordingPrimaryArtistRemovedEvent>().length(), 0);
    assert_eq!(events_by_type<credits::RecordingFeaturedArtistAddedEvent>().length(), 0);
    assert_eq!(events_by_type<credits::RecordingFeaturedArtistRemovedEvent>().length(), 0);

    test_scenario::return_shared(rec);

    destroy(cap);
    destroy(lead); destroy(lead_cap);
    destroy(guest); destroy(guest_cap);
    ts.end();
}

/// Post-publish removal: the admin removes both credits on the shared recording
/// (cascading their designations), which detaches the record; a stranger sees
/// no credits, and re-designating a removed party aborts `ENoCredits`.
#[test, expected_failure(abort_code = credits::ENoCredits)]
fun remove_credit_then_add_primary_fails_on_published_recording() {
    let mut ts = test_scenario::begin(ADMIN);
    let cap = publish_shared_recording(&mut ts);

    // --- Tx 2 (ADMIN): credits, designations, then removals ---
    ts.next_tx(ADMIN);
    let mut rec = ts.take_shared<Recording<TestShare>>();
    let (p, _pc) = mk_party(b"Alice Party", ts.ctx());
    let (featured, _featured_pc) = mk_party(b"Featured Party", ts.ctx());
    let pid = object::id(&p);
    let featured_id = object::id(&featured);
    let recording_id = object::id(&rec);
    credits::add_credit(&mut rec, &cap, &p, vocalist(b"Alice Display"));
    credits::add_credit(&mut rec, &cap, &featured, producer(b"Featured Display"));
    credits::add_primary_artist(&mut rec, &cap, object::id(&p));
    credits::add_featured_artist(&mut rec, &cap, object::id(&featured));
    credits::remove_credit(&mut rec, &cap, pid);
    credits::remove_credit(&mut rec, &cap, featured_id);

    let removed = events_by_type<credits::RecordingCreditRemovedEvent>();
    assert_eq!(removed.length(), 2);
    let (event_object, event_party) = credits::recording_credit_removed_fields(&removed[0]);
    assert_eq!(event_object, recording_id);
    assert_eq!(event_party, pid);
    let (event_object, event_party) = credits::recording_credit_removed_fields(&removed[1]);
    assert_eq!(event_object, recording_id);
    assert_eq!(event_party, featured_id);

    // The cascade ends both designations, each with its own event.
    let primary_removed = events_by_type<credits::RecordingPrimaryArtistRemovedEvent>();
    assert_eq!(primary_removed.length(), 1);
    let (event_object, event_party) =
        credits::recording_primary_artist_removed_fields(&primary_removed[0]);
    assert_eq!(event_object, recording_id);
    assert_eq!(event_party, pid);
    let featured_removed = events_by_type<credits::RecordingFeaturedArtistRemovedEvent>();
    assert_eq!(featured_removed.length(), 1);
    let (event_object, event_party) =
        credits::recording_featured_artist_removed_fields(&featured_removed[0]);
    assert_eq!(event_object, recording_id);
    assert_eq!(event_party, featured_id);
    assert!(!credits::is_primary_artist(&rec, pid));
    assert!(!credits::is_featured_artist(&rec, featured_id));

    test_scenario::return_shared(rec);

    // --- Tx 3 (STRANGER): confirms the removal is visible before the
    // adversarial re-operate attempt below ---
    ts.next_tx(STRANGER);
    let rec = ts.take_shared<Recording<TestShare>>();
    assert!(!credits::has_credits(&rec));
    test_scenario::return_shared(rec);

    // --- Tx 4 (ADMIN): re-operating on the removed party must abort ---
    ts.next_tx(ADMIN);
    let mut rec = ts.take_shared<Recording<TestShare>>();
    credits::add_primary_artist(&mut rec, &cap, object::id(&p));
    abort
}
