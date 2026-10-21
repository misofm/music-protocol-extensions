// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// What a release says about itself, the paragraph under the title, written by
/// the holder of the release's admin cap. A free string that nothing on-chain
/// reads, stored exactly as given in one slot. The 8 KB ceiling is storage
/// hygiene; an empty string is rejected because absence already means "no
/// description". The set event carries the full text.
module release_description::release_description;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use miso_music::release::{Release, ReleaseAdminCap};

// === Errors ===

/// No description is attached to this release.
const ENoDescription: u64 = 0;
/// The description is empty.
const EEmptyDescription: u64 = 1;
/// The description exceeds `MAX_DESCRIPTION_LENGTH` bytes.
const EDescriptionTooLong: u64 = 2;

// === Constants ===

/// Maximum length of a description, in bytes (not characters): 8 KB, roughly
/// 1,300 words of English prose.
const MAX_DESCRIPTION_LENGTH: u64 = 8192;

// === Structs ===

/// Dynamic-field key: one description (`String`) per release.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when a release's description is set or replaced with a different
/// value, with the new text.
public struct ReleaseDescriptionSetEvent has copy, drop {
    release_id: ID,
    description: String,
}

/// Emitted when an attached description is removed.
public struct ReleaseDescriptionClearedEvent has copy, drop {
    release_id: ID,
}

// === Public Functions ===

/// Sets (or replaces) what the release says about itself, stored exactly as
/// given. Aborts `EEmptyDescription` on an empty string and
/// `EDescriptionTooLong` past `MAX_DESCRIPTION_LENGTH` bytes, both before
/// cap authorization. Setting the value already stored neither writes nor
/// emits.
public fun set_description(self: &mut Release, cap: &ReleaseAdminCap, description: String) {
    assert!(!description.is_empty(), EEmptyDescription);
    assert!(description.length() <= MAX_DESCRIPTION_LENGTH, EDescriptionTooLong);

    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let stored: &mut String = df::borrow_mut(uid, ExtensionKey());
        if (*stored == description) return;
        *stored = description;
    } else {
        df::add(uid, ExtensionKey(), description);
    };
    emit(ReleaseDescriptionSetEvent { release_id, description });
}

/// Removes the description, if any. Authorizes first; an absent description
/// is a silent no-op.
public fun clear_description(self: &mut Release, cap: &ReleaseAdminCap) {
    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: String = df::remove(uid, ExtensionKey());
        emit(ReleaseDescriptionClearedEvent { release_id });
    }
}

// === View Functions ===

/// Whether a description is attached to this release.
public fun has_description(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// What the release says about itself. Aborts `ENoDescription` if nothing is
/// attached.
public fun description(self: &Release): &String {
    assert!(has_description(self), ENoDescription);
    df::borrow(self.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun release_description_set_fields(e: &ReleaseDescriptionSetEvent): (ID, String) {
    (e.release_id, e.description)
}

#[test_only]
public fun release_description_cleared_fields(e: &ReleaseDescriptionClearedEvent): ID {
    e.release_id
}
