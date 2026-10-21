// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// The parental advisory for a recording, stored as a dynamic field on the
/// recording's UID and written through its cap-gated `uid_mut`. `Cleaned` (an
/// explicit recording re-issued with the content removed) is its own variant.
/// A present value has been asserted by the rights holder; absence means
/// nothing was asserted and is distinct from `NotExplicit`.
module recording_advisory::recording_advisory;

// === Imports ===

use sui::dynamic_field as df;
use sui::event::emit;
use musicos::recording::{Recording, RecordingAdminCap};

// === Errors ===

/// No advisory is attached to this recording.
const ENoAdvisory: u64 = 0;

// === Structs ===

/// Dynamic-field key: one `Advisory` per recording.
public struct ExtensionKey() has copy, drop, store;

// === Enums ===

/// A recording's parental advisory.
public enum Advisory has copy, drop, store {
    /// Contains explicit content.
    Explicit,
    /// Contains no explicit content, and never did.
    NotExplicit,
    /// An edited version of a recording that was originally explicit.
    Cleaned,
}

// === Events ===

/// Emitted when the advisory is set to a value it did not already hold.
public struct RecordingAdvisorySetEvent has copy, drop {
    recording_id: ID,
    advisory: Advisory,
}

/// Emitted when an attached advisory is removed.
public struct RecordingAdvisoryClearedEvent has copy, drop {
    recording_id: ID,
}

// === Public Functions ===

/// Contains explicit content.
public fun explicit(): Advisory { Advisory::Explicit }

/// Contains no explicit content, and never did.
public fun not_explicit(): Advisory { Advisory::NotExplicit }

/// An edited version of a recording that was originally explicit.
public fun cleaned(): Advisory { Advisory::Cleaned }

/// Sets (or replaces) the recording's advisory. Setting the value already
/// held neither writes nor emits.
public fun set_advisory<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    advisory: Advisory,
) {
    let recording_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let current: &mut Advisory = df::borrow_mut(uid, ExtensionKey());
        if (*current == advisory) return;
        *current = advisory;
    } else {
        df::add(uid, ExtensionKey(), advisory);
    };
    emit(RecordingAdvisorySetEvent { recording_id, advisory });
}

/// Removes the advisory, if any. Silent when nothing is attached. Leaves the
/// recording having said nothing, which is distinct from `NotExplicit`.
public fun clear_advisory<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    let recording_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: Advisory = df::remove(uid, ExtensionKey());
        emit(RecordingAdvisoryClearedEvent { recording_id });
    }
}

// === View Functions ===

/// Whether an advisory is attached to this recording.
public fun has_advisory<RecordingShare>(self: &Recording<RecordingShare>): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The recording's advisory. Aborts `ENoAdvisory` when none is attached;
/// absence must not be read as `NotExplicit`.
public fun advisory<RecordingShare>(self: &Recording<RecordingShare>): Advisory {
    assert!(has_advisory(self), ENoAdvisory);
    *df::borrow(self.uid(), ExtensionKey())
}

/// Whether the advisory is `Explicit`.
public fun is_explicit(self: &Advisory): bool {
    match (self) { Advisory::Explicit => true, _ => false }
}

/// Whether the advisory is `NotExplicit`.
public fun is_not_explicit(self: &Advisory): bool {
    match (self) { Advisory::NotExplicit => true, _ => false }
}

/// Whether the advisory is `Cleaned`.
public fun is_cleaned(self: &Advisory): bool {
    match (self) { Advisory::Cleaned => true, _ => false }
}

// === Test Functions ===

#[test_only]
public fun recording_advisory_set_fields(e: &RecordingAdvisorySetEvent): (ID, Advisory) {
    (e.recording_id, e.advisory)
}

#[test_only]
public fun recording_advisory_cleared_fields(e: &RecordingAdvisoryClearedEvent): ID {
    e.recording_id
}
