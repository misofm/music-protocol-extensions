// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// What a release calls itself ("Album", "EP", "Mixtape", "Split"). A free string rather than an
/// enum: nothing depends on two releases agreeing about what an EP is. Stored verbatim, so "EP"
/// and "ep" are distinct; clients normalise if they group.
module release_kind::release_kind;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use miso_music::release::{Release, ReleaseAdminCap};

// === Errors ===

const ENoKind: u64 = 0;
const EEmptyKind: u64 = 1;
const EKindTooLong: u64 = 2;

// === Constants ===

/// In bytes. Fits the long forms ("Extended Play", "Album (Deluxe Edition)"); anything longer is
/// a title, not a kind.
const MAX_KIND_LENGTH: u64 = 32;

// === Structs ===

public struct ExtensionKey() has copy, drop, store;

// === Events ===

public struct ReleaseKindSetEvent has copy, drop {
    release_id: ID,
    kind: String,
}

public struct ReleaseKindClearedEvent has copy, drop {
    release_id: ID,
}

// === Public Functions ===

/// Setting the value already stored neither writes nor emits.
public fun set_kind(self: &mut Release, cap: &ReleaseAdminCap, kind: String) {
    assert!(!kind.is_empty(), EEmptyKind);
    assert!(kind.length() <= MAX_KIND_LENGTH, EKindTooLong);

    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let stored: &mut String = df::borrow_mut(uid, ExtensionKey());
        if (*stored == kind) return;
        *stored = kind;
    } else {
        df::add(uid, ExtensionKey(), kind);
    };
    emit(ReleaseKindSetEvent { release_id, kind });
}

/// An absent kind is a no-op, but the cap is still checked.
public fun clear_kind(self: &mut Release, cap: &ReleaseAdminCap) {
    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: String = df::remove(uid, ExtensionKey());
        emit(ReleaseKindClearedEvent { release_id });
    }
}

// === View Functions ===

public fun has_kind(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

public fun kind(self: &Release): &String {
    assert!(has_kind(self), ENoKind);
    df::borrow(self.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun release_kind_set_fields(e: &ReleaseKindSetEvent): (ID, String) {
    (e.release_id, e.kind)
}

#[test_only]
public fun release_kind_cleared_fields(e: &ReleaseKindClearedEvent): ID {
    e.release_id
}
