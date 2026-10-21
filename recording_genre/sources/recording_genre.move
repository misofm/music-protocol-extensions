// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// The genres that classify a recording, in order with the primary first,
/// stored as a dynamic field on the recording's UID and written through its
/// cap-gated `uid_mut`. Genre is a fact about the audio, so it lives on the
/// recording; `release_genre` holds the separate product-level claim.
///
/// The value is a `vector<ID>` of `genre::Genre` ids, index 0 the primary,
/// capped at `MAX_GENRES`. Every add takes `&Genre`, so only real vocabulary
/// entries can enter. The field exists exactly when at least one genre is
/// attached. Reordering is `clear_genres` then `add_genre` in one PTB.
module recording_genre::recording_genre;

// === Imports ===

use sui::dynamic_field as df;
use sui::event::emit;
use genre::genre::Genre;
use miso_music::recording::{Recording, RecordingAdminCap};

// === Errors ===

/// The genre is already assigned to this recording.
const EDuplicateGenre: u64 = 0;
/// The recording already carries `MAX_GENRES` genres.
const EMaxGenresExceeded: u64 = 1;
/// No genres are attached to this recording.
const ENoGenres: u64 = 2;
/// The genre is not assigned to this recording.
const EGenreNotFound: u64 = 3;

// === Constants ===

/// Maximum genres on one recording: the primary plus up to five more.
const MAX_GENRES: u64 = 6;

// === Structs ===

/// Dynamic-field key: one ordered `vector<ID>` of genres per recording.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when a genre is appended; the first add makes it the primary.
public struct RecordingGenreAddedEvent has copy, drop {
    recording_id: ID,
    genre_id: ID,
}

/// Emitted when a genre is removed. Removing the last genre drops the field
/// and emits only this event.
public struct RecordingGenreRemovedEvent has copy, drop {
    recording_id: ID,
    genre_id: ID,
}

/// Emitted when `clear_genres` removes an attached list.
public struct RecordingGenresClearedEvent has copy, drop {
    recording_id: ID,
}

// === Public Functions ===

/// Appends a genre to the recording's list, creating the field on first use
/// so that genre becomes the primary. Aborts `EDuplicateGenre` if already
/// present, then `EMaxGenresExceeded` if the recording is at capacity.
public fun add_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    genre: &Genre,
) {
    let recording_id = object::id(self);
    let genre_id = object::id(genre);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let genres: &mut vector<ID> = df::borrow_mut(uid, ExtensionKey());
        assert!(!genres.contains(&genre_id), EDuplicateGenre);
        assert!(genres.length() < MAX_GENRES, EMaxGenresExceeded);
        genres.push_back(genre_id);
    } else {
        df::add(uid, ExtensionKey(), vector[genre_id]);
    };
    emit(RecordingGenreAddedEvent { recording_id, genre_id });
}

/// Removes a genre by id; if it was the primary, the next genre becomes
/// primary. Removing the last genre drops the field. Aborts `ENoGenres` when
/// nothing is attached and `EGenreNotFound` when the genre is not assigned.
public fun remove_genre<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
    genre_id: ID,
) {
    let recording_id = object::id(self);
    let uid = self.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey()), ENoGenres);
    let genres: &mut vector<ID> = df::borrow_mut(uid, ExtensionKey());
    let (found, index) = genres.index_of(&genre_id);
    assert!(found, EGenreNotFound);
    genres.remove(index);
    if (genres.is_empty()) {
        let _: vector<ID> = df::remove(uid, ExtensionKey());
    };
    emit(RecordingGenreRemovedEvent { recording_id, genre_id });
}

/// Removes the recording's entire genre list. Silent when nothing is attached.
public fun clear_genres<RecordingShare>(
    self: &mut Recording<RecordingShare>,
    cap: &RecordingAdminCap<RecordingShare>,
) {
    let recording_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: vector<ID> = df::remove(uid, ExtensionKey());
        emit(RecordingGenresClearedEvent { recording_id });
    }
}

// === View Functions ===

/// Whether at least one genre is attached to this recording.
public fun has_genres<RecordingShare>(self: &Recording<RecordingShare>): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The recording's genre ids in order, primary first. Aborts `ENoGenres` when
/// nothing is attached.
public fun genres<RecordingShare>(self: &Recording<RecordingShare>): &vector<ID> {
    assert!(has_genres(self), ENoGenres);
    df::borrow(self.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun recording_genre_added_fields(e: &RecordingGenreAddedEvent): (ID, ID) {
    (e.recording_id, e.genre_id)
}

#[test_only]
public fun recording_genre_removed_fields(e: &RecordingGenreRemovedEvent): (ID, ID) {
    (e.recording_id, e.genre_id)
}

#[test_only]
public fun recording_genres_cleared_fields(e: &RecordingGenresClearedEvent): ID {
    e.recording_id
}
