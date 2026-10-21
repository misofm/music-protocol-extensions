// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// Lyrics per ISO 639-1 language. Payload convention: UTF-8 text compressed into one
/// self-contained Zstandard frame without an external dictionary. Move stores opaque bytes and
/// does not decode, validate, or attest to the lyrics or their language.
module composition_lyrics::composition_lyrics;

// === Imports ===

use std::string::String;
use sui::dynamic_field as df;
use sui::event::emit;
use language_code::language_code::LanguageCode;
use miso_music::composition::{Composition, CompositionAdminCap};

// === Errors ===

const ENoLyrics: u64 = 0;
const EEmptyLyrics: u64 = 1;
const ELyricsTooLong: u64 = 2;

// === Constants ===

/// Storage bound per language, in compressed bytes. Not a decoded text limit.
const MAX_LYRICS_LENGTH: u64 = 32768;

// === Structs ===

public struct ExtensionKey(LanguageCode) has copy, drop, store;

// === Events ===

public struct CompositionLyricsSetEvent has copy, drop {
    composition_id: ID,
    language: String,
    lyrics: vector<u8>,
}

public struct CompositionLyricsClearedEvent has copy, drop {
    composition_id: ID,
    language: String,
}

// === Public Functions ===

/// Setting the bytes already stored neither writes nor emits.
public fun set_lyrics<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    language: LanguageCode,
    lyrics: vector<u8>,
) {
    assert!(!lyrics.is_empty(), EEmptyLyrics);
    assert!(lyrics.length() <= MAX_LYRICS_LENGTH, ELyricsTooLong);

    let composition_id = object::id(self);
    let uid = self.uid_mut(cap);
    let key = ExtensionKey(language);
    if (df::exists(uid, key)) {
        let stored: &mut vector<u8> = df::borrow_mut(uid, key);
        if (*stored == lyrics) return;
        *stored = lyrics;
    } else {
        df::add(uid, key, lyrics);
    };
    emit(CompositionLyricsSetEvent { composition_id, language: language.code(), lyrics });
}

/// An absent entry is a no-op, but the cap is still checked.
public fun clear_lyrics<CompositionShare>(
    self: &mut Composition<CompositionShare>,
    cap: &CompositionAdminCap<CompositionShare>,
    language: LanguageCode,
) {
    let composition_id = object::id(self);
    let uid = self.uid_mut(cap);
    let key = ExtensionKey(language);
    if (df::exists(uid, key)) {
        let _: vector<u8> = df::remove(uid, key);
        emit(CompositionLyricsClearedEvent {
            composition_id,
            language: language.code(),
        });
    }
}

// === View Functions ===

public fun has_lyrics<CompositionShare>(
    self: &Composition<CompositionShare>,
    language: LanguageCode,
): bool {
    df::exists(self.uid(), ExtensionKey(language))
}

public fun lyrics<CompositionShare>(
    self: &Composition<CompositionShare>,
    language: LanguageCode,
): &vector<u8> {
    assert!(has_lyrics(self, language), ENoLyrics);
    df::borrow(self.uid(), ExtensionKey(language))
}

public fun max_lyrics_length(): u64 { MAX_LYRICS_LENGTH }

// === Test Functions ===

#[test_only]
public fun composition_lyrics_set_fields(
    e: &CompositionLyricsSetEvent,
): (ID, String, vector<u8>) {
    (e.composition_id, e.language, e.lyrics)
}

#[test_only]
public fun composition_lyrics_cleared_fields(e: &CompositionLyricsClearedEvent): (ID, String) {
    (e.composition_id, e.language)
}
