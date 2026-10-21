// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// The paragraph under the release title. A free string that nothing on-chain reads, stored
/// exactly as given. An empty string is rejected because absence already means "no description".
module release_description::release_description;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use miso_music::release::{Release, ReleaseAdminCap};

// === Errors ===

const ENoDescription: u64 = 0;
const EEmptyDescription: u64 = 1;
const EDescriptionTooLong: u64 = 2;

// === Constants ===

/// In bytes, not characters: 8 KB, roughly 1,300 words of English prose. Storage hygiene only.
const MAX_DESCRIPTION_LENGTH: u64 = 8192;

// === Structs ===

public struct ExtensionKey() has copy, drop, store;

// === Events ===

public struct ReleaseDescriptionSetEvent has copy, drop {
    release_id: ID,
    description: String,
}

public struct ReleaseDescriptionClearedEvent has copy, drop {
    release_id: ID,
}

// === Public Functions ===

/// Setting the value already stored neither writes nor emits.
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

/// An absent description is a no-op, but the cap is still checked.
public fun clear_description(self: &mut Release, cap: &ReleaseAdminCap) {
    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: String = df::remove(uid, ExtensionKey());
        emit(ReleaseDescriptionClearedEvent { release_id });
    }
}

// === View Functions ===

public fun has_description(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

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
