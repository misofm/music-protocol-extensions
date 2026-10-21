// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// A composition's preferred title, written by the holder of the composition's
/// admin cap and stored exactly as given under this module's key. It can be set
/// before publication and corrected after it; nothing on-chain reads it.
///
/// Argument validation runs before the cap is consulted; stored-state checks
/// run after `uid_mut`. An equal set or a clear of nothing writes and emits
/// nothing, so every event is a transition.
module composition_title::composition_title;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use musicos::composition::{Composition, CompositionAdminCap};

// === Errors ===

/// No title is attached to this composition.
const ENoTitle: u64 = 0;
/// The title is empty. Naming nothing is done by not attaching.
const EEmptyTitle: u64 = 1;
/// The title exceeds `MAX_TITLE_LENGTH` bytes.
const ETitleTooLong: u64 = 2;

// === Constants ===

/// Maximum length of a title, in bytes; a multi-byte title fits fewer characters.
const MAX_TITLE_LENGTH: u64 = 300;

// === Structs ===

/// Dynamic-field key: one `String` title per composition.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when a title is added or replaced with a different value.
public struct CompositionTitleSetEvent has copy, drop {
    composition_id: ID,
    title: String,
}

/// Emitted when an attached title is removed.
public struct CompositionTitleClearedEvent has copy, drop {
    composition_id: ID,
}

// === Public Functions ===

/// Sets (or replaces) the title, stored exactly as given. Aborts `EEmptyTitle`
/// for an empty string, then `ETitleTooLong` above `MAX_TITLE_LENGTH` bytes,
/// both before the cap is consulted. Setting the title already attached is a
/// no-op after the cap check.
public fun set_title<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    title: String,
) {
    let bytes = title.as_bytes();
    assert!(!bytes.is_empty(), EEmptyTitle);
    assert!(bytes.length() <= MAX_TITLE_LENGTH, ETitleTooLong);

    let composition_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let stored: &mut String = df::borrow_mut(uid, ExtensionKey());
        if (*stored == title) return;
        *stored = title;
    } else {
        df::add(uid, ExtensionKey(), title);
    };
    emit(CompositionTitleSetEvent { composition_id, title });
}

/// Removes the title, if any. Authorizes before it looks, so a clear of
/// nothing still requires the cap and is then silent.
public fun clear_title<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
) {
    let composition_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (!df::exists(uid, ExtensionKey())) return;
    let _: String = df::remove(uid, ExtensionKey());
    emit(CompositionTitleClearedEvent { composition_id });
}

// === View Functions ===

/// Whether a title is attached to this composition.
public fun has_title<CompositionShare>(self: &Composition<CompositionShare>): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The composition's title. Aborts `ENoTitle` if nothing is attached.
public fun title<CompositionShare>(self: &Composition<CompositionShare>): &String {
    assert!(has_title(self), ENoTitle);
    df::borrow(self.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun composition_title_set_fields(e: &CompositionTitleSetEvent): (ID, String) {
    (e.composition_id, e.title)
}

#[test_only]
public fun composition_title_cleared_fields(e: &CompositionTitleClearedEvent): ID {
    e.composition_id
}
