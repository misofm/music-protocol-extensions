// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

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

public fun set_description(release: &mut Release, cap: &ReleaseAdminCap, description: String) {
    assert!(!description.is_empty(), EEmptyDescription);
    assert!(description.length() <= MAX_DESCRIPTION_LENGTH, EDescriptionTooLong);

    let release_id = object::id(release);
    let uid = release.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let stored: &mut String = df::borrow_mut(uid, ExtensionKey());
        if (*stored == description) return;
        *stored = description;
    } else {
        df::add(uid, ExtensionKey(), description);
    };
    emit(ReleaseDescriptionSetEvent { release_id, description });
}

public fun clear_description(release: &mut Release, cap: &ReleaseAdminCap) {
    let release_id = object::id(release);
    let uid = release.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: String = df::remove(uid, ExtensionKey());
        emit(ReleaseDescriptionClearedEvent { release_id });
    }
}

// === View Functions ===

public fun has_description(release: &Release): bool {
    df::exists(release.uid(), ExtensionKey())
}

public fun description(release: &Release): &String {
    assert!(has_description(release), ENoDescription);
    df::borrow(release.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun release_description_set_fields(event: &ReleaseDescriptionSetEvent): (ID, String) {
    (event.release_id, event.description)
}

#[test_only]
public fun release_description_cleared_fields(event: &ReleaseDescriptionClearedEvent): ID {
    event.release_id
}
