// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

module recording_language::recording_language;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use sui::vec_set;
use language_code::language_code::LanguageCode;
use miso_music::recording::{Recording, RecordingAdminCap};

// === Errors ===

const ENoLanguages: u64 = 0;
const EMaxLanguagesExceeded: u64 = 1;
const EDuplicateLanguage: u64 = 2;

// === Constants ===

const MAX_LANGUAGES: u64 = 10;

// === Structs ===

public struct ExtensionKey() has copy, drop, store;

// === Events ===

public struct RecordingLanguagesSetEvent has copy, drop {
    recording_id: ID,
    languages: vector<String>,
}

public struct RecordingLanguagesClearedEvent has copy, drop {
    recording_id: ID,
}

// === View Functions ===

public fun has_languages<RecordingShare>(recording: &Recording<RecordingShare>): bool {
    df::exists(recording.uid(), ExtensionKey())
}

public fun languages<RecordingShare>(
    recording: &Recording<RecordingShare>,
): &vector<LanguageCode> {
    assert!(has_languages(recording), ENoLanguages);
    df::borrow(recording.uid(), ExtensionKey())
}

// === Admin Functions ===

public fun set_languages<RecordingShare>(
    recording: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    languages: vector<LanguageCode>,
) {
    assert!(languages.length() <= MAX_LANGUAGES, EMaxLanguagesExceeded);
    let mut seen = vec_set::empty<LanguageCode>();
    languages.do_ref!(|language| {
        assert!(!seen.contains(language), EDuplicateLanguage);
        seen.insert(*language);
    });
    let recording_id = object::id(recording);
    let uid = recording.uid_mut(cap);
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

public fun clear_languages<RecordingShare>(
    recording: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    let recording_id = object::id(recording);
    let uid = recording.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: vector<LanguageCode> = df::remove(uid, ExtensionKey());
        emit(RecordingLanguagesClearedEvent { recording_id });
    }
}

// === Test Functions ===

#[test_only]
public fun recording_languages_set_fields(
    event: &RecordingLanguagesSetEvent,
): (ID, vector<String>) {
    (event.recording_id, event.languages)
}

#[test_only]
public fun recording_languages_cleared_fields(event: &RecordingLanguagesClearedEvent): ID {
    event.recording_id
}
