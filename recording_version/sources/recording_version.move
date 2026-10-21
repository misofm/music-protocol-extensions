// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// The version name of a recording, which take of the composition it is
/// ("Live", "Radio Edit", "Acoustic"), stored as a dynamic field on the
/// recording's UID and written through its cap-gated `uid_mut`. A recording
/// displays as its composition's title plus this name; absence means the plain
/// rendition. The value is a non-empty UTF-8 `String` of at most
/// `MAX_VERSION_LENGTH` bytes.
module recording_version::recording_version;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use musicos::recording::{Recording, RecordingAdminCap};

// === Errors ===

/// No version name is attached to this recording.
const ENoVersion: u64 = 0;
/// The version name is empty.
const EEmptyVersion: u64 = 1;
/// The version name exceeds `MAX_VERSION_LENGTH` bytes.
const EVersionTooLong: u64 = 2;

// === Constants ===

/// Maximum version name length in bytes.
const MAX_VERSION_LENGTH: u64 = 300;

// === Structs ===

/// Dynamic-field key: one version name per recording.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when the version name is set to a value it did not already hold.
public struct RecordingVersionSetEvent has copy, drop {
    recording_id: ID,
    version: String,
}

/// Emitted when an attached version name is removed.
public struct RecordingVersionClearedEvent has copy, drop {
    recording_id: ID,
}

// === Public Functions ===

/// Sets (or replaces) the recording's version name. Aborts `EEmptyVersion`
/// on an empty string and `EVersionTooLong` past `MAX_VERSION_LENGTH` bytes.
/// Setting the value already held neither writes nor emits.
public fun set_version<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    version: String,
) {
    assert!(!version.is_empty(), EEmptyVersion);
    assert!(version.length() <= MAX_VERSION_LENGTH, EVersionTooLong);
    let recording_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let current: &mut String = df::borrow_mut(uid, ExtensionKey());
        if (*current == version) return;
        *current = version;
    } else {
        df::add(uid, ExtensionKey(), version);
    };
    emit(RecordingVersionSetEvent { recording_id, version });
}

/// Removes the version name, if any. Silent when nothing is attached.
public fun clear_version<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    let recording_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: String = df::remove(uid, ExtensionKey());
        emit(RecordingVersionClearedEvent { recording_id });
    }
}

// === View Functions ===

/// Whether a version name is attached to this recording.
public fun has_version<RecordingShare>(self: &Recording<RecordingShare>): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The recording's version name. Aborts `ENoVersion` when none is attached.
public fun version<RecordingShare>(self: &Recording<RecordingShare>): &String {
    assert!(has_version(self), ENoVersion);
    df::borrow(self.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun recording_version_set_fields(e: &RecordingVersionSetEvent): (ID, String) {
    (e.recording_id, e.version)
}

#[test_only]
public fun recording_version_cleared_fields(e: &RecordingVersionClearedEvent): ID {
    e.recording_id
}
