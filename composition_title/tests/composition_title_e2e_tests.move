// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// End-to-end scenarios under `sui::test_scenario`: real transaction
/// boundaries, distinct senders, the admin cap held as an owned object, and
/// the composition published and shared. A composition cannot outlive its
/// creating transaction unpublished, so "before publish" means earlier in the
/// same transaction.
#[test_only]
module composition_title::composition_title_e2e_tests;

// === Imports ===

use std::unit_test::assert_eq;
use sui::event;
use sui::test_scenario::{Self, Scenario};
use musicos::composition::{Self, Composition, CompositionAdminCap};
use composition_title::composition_title as ct;

const WRITER: address = @0xA0;
const STRANGER: address = @0x51;

public struct TestShare() has drop;

/// Publishes and shares a composition in the current transaction, sending
/// its admin cap to the sender so later transactions take it from inventory,
/// as a wallet would. Returns the composition's id.
fun publish_composition(scenario: &mut Scenario, sender: address): ID {
    let (comp, cap) = composition::new_for_testing<TestShare>(scenario.ctx());
    let comp_id = object::id(&comp);
    comp.publish(&cap);
    transfer::public_transfer(cap, sender);
    comp_id
}

/// WRITER names the composition before publishing it, in the same
/// transaction that publishes and shares it; the title survives publication,
/// a stranger reads it, and WRITER corrects it later against the shared object.
#[test]
fun title_set_before_publish_survives_publication() {
    let mut ts = test_scenario::begin(WRITER);

    // --- Tx 1 (WRITER): create, name, publish and share ---
    let (mut comp, cap) = composition::new_for_testing<TestShare>(ts.ctx());
    let comp_id = object::id(&comp);
    ct::set_title(&mut comp, &cap, b"So What".to_string());
    assert_eq!(*ct::title(&comp), b"So What".to_string());
    comp.publish(&cap);
    transfer::public_transfer(cap, WRITER);

    let sets = event::events_by_type<ct::CompositionTitleSetEvent>();
    assert_eq!(sets.length(), 1);
    let (event_id, title) = ct::composition_title_set_fields(&sets[0]);
    assert_eq!(event_id, comp_id);
    assert_eq!(title, b"So What".to_string());

    // --- Tx 2 (STRANGER): the title is on the published, shared object ---
    ts.next_tx(STRANGER);
    let comp = ts.take_shared<Composition<TestShare>>();
    assert_eq!(*ct::title(&comp), b"So What".to_string());
    test_scenario::return_shared(comp);

    // --- Tx 3 (WRITER): a correction after publish, cap taken from inventory ---
    ts.next_tx(WRITER);
    let mut comp = ts.take_shared<Composition<TestShare>>();
    let cap = ts.take_from_sender<CompositionAdminCap<TestShare>>();
    ct::set_title(&mut comp, &cap, b"So What (Alternate Take)".to_string());
    ts.return_to_sender(cap);
    test_scenario::return_shared(comp);

    // --- Tx 4 (STRANGER): sees the correction ---
    ts.next_tx(STRANGER);
    let comp = ts.take_shared<Composition<TestShare>>();
    assert_eq!(*ct::title(&comp), b"So What (Alternate Take)".to_string());
    test_scenario::return_shared(comp);

    ts.end();
}

/// WRITER publishes an unnamed composition, then names, renames and clears it
/// in later transactions via `take_shared`; a stranger observes each state.
#[test]
fun title_lifecycle_on_a_published_and_shared_composition() {
    let mut ts = test_scenario::begin(WRITER);

    // --- Tx 1 (WRITER): publish and share, unnamed ---
    let comp_id = publish_composition(&mut ts, WRITER);

    // --- Tx 2 (STRANGER): readable by anyone, and starts empty ---
    ts.next_tx(STRANGER);
    let comp = ts.take_shared<Composition<TestShare>>();
    assert!(!ct::has_title(&comp));
    test_scenario::return_shared(comp);

    // --- Tx 3 (WRITER): names it ---
    ts.next_tx(WRITER);
    let mut comp = ts.take_shared<Composition<TestShare>>();
    let cap = ts.take_from_sender<CompositionAdminCap<TestShare>>();
    ct::set_title(&mut comp, &cap, b"Freddie Freeloader".to_string());
    assert!(ct::has_title(&comp));
    ts.return_to_sender(cap);
    test_scenario::return_shared(comp);

    let sets = event::events_by_type<ct::CompositionTitleSetEvent>();
    assert_eq!(sets.length(), 1);
    let (event_id, title) = ct::composition_title_set_fields(&sets[0]);
    assert_eq!(event_id, comp_id);
    assert_eq!(title, b"Freddie Freeloader".to_string());

    // --- Tx 4 (STRANGER): reads back the same title a transaction later ---
    ts.next_tx(STRANGER);
    let comp = ts.take_shared<Composition<TestShare>>();
    assert_eq!(*ct::title(&comp), b"Freddie Freeloader".to_string());
    test_scenario::return_shared(comp);

    // --- Tx 5 (WRITER): equal set is silent; rename, then clear ---
    ts.next_tx(WRITER);
    let mut comp = ts.take_shared<Composition<TestShare>>();
    let cap = ts.take_from_sender<CompositionAdminCap<TestShare>>();
    ct::set_title(&mut comp, &cap, b"Freddie Freeloader".to_string());
    assert_eq!(event::num_events(), 0);
    ct::set_title(&mut comp, &cap, b"Freddie the Freeloader".to_string());
    ct::clear_title(&mut comp, &cap);
    assert!(!ct::has_title(&comp));
    ts.return_to_sender(cap);
    test_scenario::return_shared(comp);

    let sets = event::events_by_type<ct::CompositionTitleSetEvent>();
    assert_eq!(sets.length(), 1);
    let (event_id, title) = ct::composition_title_set_fields(&sets[0]);
    assert_eq!(event_id, comp_id);
    assert_eq!(title, b"Freddie the Freeloader".to_string());
    let clears = event::events_by_type<ct::CompositionTitleClearedEvent>();
    assert_eq!(clears.length(), 1);
    assert_eq!(ct::composition_title_cleared_fields(&clears[0]), comp_id);

    // --- Tx 6 (STRANGER): the clear is visible too ---
    ts.next_tx(STRANGER);
    let comp = ts.take_shared<Composition<TestShare>>();
    assert!(!ct::has_title(&comp));
    test_scenario::return_shared(comp);

    ts.end();
}

/// Two published compositions keep independent titles and use their own
/// object-bound admin capabilities.
#[test]
fun two_shared_compositions_keep_independent_titles() {
    let mut ts = test_scenario::begin(WRITER);
    let first_id = publish_composition(&mut ts, WRITER);

    ts.next_tx(STRANGER);
    let second_id = publish_composition(&mut ts, STRANGER);

    ts.next_tx(WRITER);
    let mut first = test_scenario::take_shared_by_id<Composition<TestShare>>(&ts, first_id);
    let cap = ts.take_from_sender<CompositionAdminCap<TestShare>>();
    ct::set_title(&mut first, &cap, b"Writer's Song".to_string());
    ts.return_to_sender(cap);
    test_scenario::return_shared(first);

    ts.next_tx(STRANGER);
    let mut second =
        test_scenario::take_shared_by_id<Composition<TestShare>>(&ts, second_id);
    let cap = ts.take_from_sender<CompositionAdminCap<TestShare>>();
    assert!(!ct::has_title(&second));
    ct::set_title(&mut second, &cap, b"Stranger's Song".to_string());
    ts.return_to_sender(cap);
    test_scenario::return_shared(second);

    ts.next_tx(STRANGER);
    let first = test_scenario::take_shared_by_id<Composition<TestShare>>(&ts, first_id);
    let second = test_scenario::take_shared_by_id<Composition<TestShare>>(&ts, second_id);
    assert_eq!(*ct::title(&first), b"Writer's Song".to_string());
    assert_eq!(*ct::title(&second), b"Stranger's Song".to_string());
    test_scenario::return_shared(first);
    test_scenario::return_shared(second);

    ts.end();
}

/// Reading after an explicit clear aborts exactly like a composition that was
/// never named — absence is absence, regardless of history.
#[test, expected_failure(abort_code = ct::ENoTitle)]
fun reading_after_clear_aborts_for_any_reader() {
    let mut ts = test_scenario::begin(WRITER);
    publish_composition(&mut ts, WRITER);

    ts.next_tx(WRITER);
    let mut comp = ts.take_shared<Composition<TestShare>>();
    let cap = ts.take_from_sender<CompositionAdminCap<TestShare>>();
    ct::set_title(&mut comp, &cap, b"Gone soon".to_string());
    ct::clear_title(&mut comp, &cap);
    ts.return_to_sender(cap);
    test_scenario::return_shared(comp);

    ts.next_tx(STRANGER);
    let comp = ts.take_shared<Composition<TestShare>>();
    let _ = ct::title(&comp);

    test_scenario::return_shared(comp);
    ts.end();
}
