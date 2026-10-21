// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// Core `Release` carries no title, so it lives here as a mutable extension. Stored verbatim; the
/// only checks are structural, and an empty string is rejected because absence already means
/// "no title".
module release_title::release_title;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use miso_music::release::{Release, ReleaseAdminCap};

// === Errors ===

const ENoTitle: u64 = 0;
const EEmptyTitle: u64 = 1;
const ETitleTooLong: u64 = 2;

// === Constants ===

/// In bytes, not characters.
const MAX_TITLE_LENGTH: u64 = 300;

// === Structs ===

public struct ExtensionKey() has copy, drop, store;

// === Events ===

public struct ReleaseTitleSetEvent has copy, drop {
    release_id: ID,
    title: String,
}

public struct ReleaseTitleClearedEvent has copy, drop {
    release_id: ID,
}

// === Public Functions ===

/// Setting the value already stored neither writes nor emits.
public fun set_title(self: &mut Release, cap: &ReleaseAdminCap, title: String) {
    assert!(!title.is_empty(), EEmptyTitle);
    assert!(title.length() <= MAX_TITLE_LENGTH, ETitleTooLong);

    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let stored: &mut String = df::borrow_mut(uid, ExtensionKey());
        if (*stored == title) return;
        *stored = title;
    } else {
        df::add(uid, ExtensionKey(), title);
    };
    emit(ReleaseTitleSetEvent { release_id, title });
}

/// An absent title is a no-op, but the cap is still checked.
public fun clear_title(self: &mut Release, cap: &ReleaseAdminCap) {
    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: String = df::remove(uid, ExtensionKey());
        emit(ReleaseTitleClearedEvent { release_id });
    }
}

// === View Functions ===

public fun has_title(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

public fun title(self: &Release): &String {
    assert!(has_title(self), ENoTitle);
    df::borrow(self.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun release_title_set_fields(e: &ReleaseTitleSetEvent): (ID, String) {
    (e.release_id, e.title)
}

#[test_only]
public fun release_title_cleared_fields(e: &ReleaseTitleClearedEvent): ID {
    e.release_id
}
