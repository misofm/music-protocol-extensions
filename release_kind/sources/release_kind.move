// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// What a release calls itself ("Album", "EP", "Mixtape", "Split"), asserted
/// by the holder of the release's admin cap. A free string rather than an
/// enum: nothing depends on two releases agreeing about what an EP is. The only
/// checks are structural (non-empty, bounded), and the value is stored
/// verbatim, so "EP" and "ep" are distinct; clients normalise if they group.
module release_kind::release_kind;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use musicos::release::{Release, ReleaseAdminCap};

// === Errors ===

/// No kind is attached to this release.
const ENoKind: u64 = 0;
/// The kind is empty.
const EEmptyKind: u64 = 1;
/// The kind exceeds `MAX_KIND_LENGTH` bytes.
const EKindTooLong: u64 = 2;

// === Constants ===

/// Maximum length of a kind, in bytes. Fits the long forms ("Extended Play",
/// "Album (Deluxe Edition)"); anything longer is a title, not a kind.
const MAX_KIND_LENGTH: u64 = 32;

// === Structs ===

/// Dynamic-field key: one kind (`String`) per release.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when a release's kind is set or replaced with a different value.
public struct ReleaseKindSetEvent has copy, drop {
    release_id: ID,
    kind: String,
}

/// Emitted when an attached kind is removed.
public struct ReleaseKindClearedEvent has copy, drop {
    release_id: ID,
}

// === Public Functions ===

/// Sets (or replaces) what the release calls itself, stored exactly as given.
/// Aborts `EEmptyKind` on an empty string and `EKindTooLong` past
/// `MAX_KIND_LENGTH` bytes, both before cap authorization. Setting the value
/// already stored neither writes nor emits.
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

/// Removes the kind, if any. Authorizes first; an absent kind is a silent
/// no-op.
public fun clear_kind(self: &mut Release, cap: &ReleaseAdminCap) {
    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: String = df::remove(uid, ExtensionKey());
        emit(ReleaseKindClearedEvent { release_id });
    }
}

// === View Functions ===

/// Whether a kind is attached to this release.
public fun has_kind(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// What the release calls itself. Aborts `ENoKind` if nothing is attached.
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
