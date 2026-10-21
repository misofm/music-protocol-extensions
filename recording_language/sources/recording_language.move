// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// The languages sung or spoken on a recording, in the caller's order (first
/// is conventionally the predominant), stored as a dynamic field on the
/// recording's UID and written through its cap-gated `uid_mut`.
///
/// An attached empty vector is an explicit instrumental claim, distinct from
/// attaching nothing. `LanguageCode` is a valid ISO 639-1 code by
/// construction, so this package checks only the count and repeats.
module recording_language::recording_language;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_set;
use language_code::language_code::LanguageCode;
use miso_music::recording::{Recording, RecordingAdminCap};

// === Errors ===

/// No language record is attached to this recording.
const ENoLanguages: u64 = 0;
/// More than `MAX_LANGUAGES` were supplied.
const EMaxLanguagesExceeded: u64 = 1;
/// The same language appears twice.
const EDuplicateLanguage: u64 = 2;

// === Constants ===

/// Maximum languages on one recording.
const MAX_LANGUAGES: u64 = 10;

// === Structs ===

/// Dynamic-field key: one `vector<LanguageCode>` per recording.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when the language list is set to a value it did not already hold.
/// `languages` holds the ordered ISO 639-1 codes; empty means instrumental.
public struct RecordingLanguagesSetEvent has copy, drop {
    recording_id: ID,
    languages: vector<String>,
}

/// Emitted when an attached language record is removed.
public struct RecordingLanguagesClearedEvent has copy, drop {
    recording_id: ID,
}

// === Public Functions ===

/// Sets (or replaces) the languages sung or spoken on the recording; an empty
/// vector asserts it is instrumental. Aborts `EMaxLanguagesExceeded` past
/// `MAX_LANGUAGES` and `EDuplicateLanguage` on a repeated code. Setting the
/// list already held neither writes nor emits.
public fun set_languages<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    languages: vector<LanguageCode>,
) {
    validate(&languages);
    let recording_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let current: &mut vector<LanguageCode> = df::borrow_mut(uid, ExtensionKey());
        if (*current == languages) return;
        *current = languages;
    } else {
        df::add(uid, ExtensionKey(), languages);
    };
    emit(RecordingLanguagesSetEvent {
        recording_id,
        languages: languages.map_ref!(|language| language.code()),
    });
}

/// Removes the language record, if any, including an instrumental claim.
/// Silent when nothing is attached.
public fun clear_languages<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    let recording_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: vector<LanguageCode> = df::remove(uid, ExtensionKey());
        emit(RecordingLanguagesClearedEvent { recording_id });
    }
}

// === View Functions ===

/// Whether a language record is attached to this recording.
public fun has_languages<RecordingShare>(self: &Recording<RecordingShare>): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The recording's languages, in the order given; empty means instrumental.
/// Aborts `ENoLanguages` when nothing is attached.
public fun languages<RecordingShare>(
    self: &Recording<RecordingShare>,
): &vector<LanguageCode> {
    assert!(has_languages(self), ENoLanguages);
    df::borrow(self.uid(), ExtensionKey())
}

// === Private Functions ===

/// Checks the count, then duplicates.
fun validate(languages: &vector<LanguageCode>) {
    assert!(languages.length() <= MAX_LANGUAGES, EMaxLanguagesExceeded);
    let mut seen = vec_set::empty<LanguageCode>();
    languages.do_ref!(|language| {
        assert!(!seen.contains(language), EDuplicateLanguage);
        seen.insert(*language);
    });
}

// === Test Functions ===

#[test_only]
public fun recording_languages_set_fields(e: &RecordingLanguagesSetEvent): (ID, vector<String>) {
    (e.recording_id, e.languages)
}

#[test_only]
public fun recording_languages_cleared_fields(e: &RecordingLanguagesClearedEvent): ID {
    e.recording_id
}
