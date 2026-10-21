// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// The title a release prefers to be known by, asserted by the holder of the
/// release's admin cap. Core `Release` carries no title, so it lives here as a
/// mutable extension. The value is stored verbatim; the only checks are
/// structural (non-empty, bounded), and an empty string is rejected because
/// absence already means "no title".
module release_title::release_title;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use miso_music::release::{Release, ReleaseAdminCap};

// === Errors ===

/// No title is attached to this release.
const ENoTitle: u64 = 0;
/// The title is empty.
const EEmptyTitle: u64 = 1;
/// The title exceeds `MAX_TITLE_LENGTH` bytes.
const ETitleTooLong: u64 = 2;

// === Constants ===

/// Maximum length of a title, in bytes (not characters). Generous enough for
/// long-form and multi-byte titles while keeping the field bounded.
const MAX_TITLE_LENGTH: u64 = 300;

// === Structs ===

/// Dynamic-field key: one title (`String`) per release.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when a release's title is set or replaced with a different value.
public struct ReleaseTitleSetEvent has copy, drop {
    release_id: ID,
    title: String,
}

/// Emitted when an attached title is removed.
public struct ReleaseTitleClearedEvent has copy, drop {
    release_id: ID,
}

// === Public Functions ===

/// Sets (or replaces) the release's title, stored exactly as given. Aborts
/// `EEmptyTitle` on an empty string and `ETitleTooLong` past
/// `MAX_TITLE_LENGTH` bytes, both before cap authorization. Setting the
/// value already stored neither writes nor emits.
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

/// Removes the title, if any. Authorizes first; an absent title is a silent
/// no-op.
public fun clear_title(self: &mut Release, cap: &ReleaseAdminCap) {
    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: String = df::remove(uid, ExtensionKey());
        emit(ReleaseTitleClearedEvent { release_id });
    }
}

// === View Functions ===

/// Whether a title is attached to this release.
public fun has_title(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The release's title. Aborts `ENoTitle` if nothing is attached.
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
