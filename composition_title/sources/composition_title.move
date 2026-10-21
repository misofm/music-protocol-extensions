// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// Stored exactly as given; it can be set before publication and corrected after, and nothing
/// on-chain reads it. An equal set or a clear of nothing writes and emits nothing, so every event
/// is a transition.
module composition_title::composition_title;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use miso_music::composition::{Composition, CompositionAdminCap};

// === Errors ===

const ENoTitle: u64 = 0;
/// Naming nothing is done by not attaching.
const EEmptyTitle: u64 = 1;
const ETitleTooLong: u64 = 2;

// === Constants ===

/// Maximum length of a title, in bytes; a multi-byte title fits fewer characters.
const MAX_TITLE_LENGTH: u64 = 300;

// === Structs ===

public struct ExtensionKey() has copy, drop, store;

// === Events ===

public struct CompositionTitleSetEvent has copy, drop {
    composition_id: ID,
    title: String,
}

public struct CompositionTitleClearedEvent has copy, drop {
    composition_id: ID,
}

// === Public Functions ===

public fun set_title<CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    title: String,
) {
    let bytes = title.as_bytes();
    assert!(!bytes.is_empty(), EEmptyTitle);
    assert!(bytes.length() <= MAX_TITLE_LENGTH, ETitleTooLong);

    let composition_id = object::id(composition);
    let uid = composition.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let stored: &mut String = df::borrow_mut(uid, ExtensionKey());
        if (*stored == title) return;
        *stored = title;
    } else {
        df::add(uid, ExtensionKey(), title);
    };
    emit(CompositionTitleSetEvent { composition_id, title });
}

/// A clear of nothing still requires the cap.
public fun clear_title<CompositionShare>(
    composition: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
) {
    let composition_id = object::id(composition);
    let uid = composition.uid_mut(cap);
    if (!df::exists(uid, ExtensionKey())) return;
    let _: String = df::remove(uid, ExtensionKey());
    emit(CompositionTitleClearedEvent { composition_id });
}

// === View Functions ===

public fun has_title<CompositionShare>(composition: &Composition<CompositionShare>): bool {
    df::exists(composition.uid(), ExtensionKey())
}

public fun title<CompositionShare>(composition: &Composition<CompositionShare>): &String {
    assert!(has_title(composition), ENoTitle);
    df::borrow(composition.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun composition_title_set_fields(event: &CompositionTitleSetEvent): (ID, String) {
    (event.composition_id, event.title)
}

#[test_only]
public fun composition_title_cleared_fields(event: &CompositionTitleClearedEvent): ID {
    event.composition_id
}
