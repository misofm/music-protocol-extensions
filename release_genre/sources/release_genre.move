// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

/// The genres a musicos `Release` is classified under as a released product,
/// stored as a dynamic field on the release's UID and written through its
/// cap-gated `uid_mut`. A recording's own genre lives in `recording_genre`;
/// clients resolve a track's genre from the recording first and fall back to
/// this release's primary.
///
/// The value is a `vector<ID>` of `genre::Genre` ids, index 0 the primary,
/// capped at `MAX_GENRES`. Every add takes `&Genre`, so only real vocabulary
/// entries can enter. The field exists exactly when at least one genre is
/// attached. Reordering is `clear_genres` then `add_genre` in one PTB.
module release_genre::release_genre;

// === Imports ===

use sui::dynamic_field as df;
use sui::event::emit;
use genre::genre::Genre;
use musicos::release::{Release, ReleaseAdminCap};

// === Errors ===

/// The genre is already assigned to this release.
const EDuplicateGenre: u64 = 0;
/// The release already carries `MAX_GENRES` genres.
const EMaxGenresExceeded: u64 = 1;
/// No genres are attached to this release.
const ENoGenres: u64 = 2;
/// The genre is not assigned to this release.
const EGenreNotFound: u64 = 3;

// === Constants ===

/// Maximum genres on one release: the primary plus up to five more.
const MAX_GENRES: u64 = 6;

// === Structs ===

/// Dynamic-field key: one ordered `vector<ID>` of genres per release.
public struct ExtensionKey() has copy, drop, store;

// === Events ===

/// Emitted when a genre is appended. The first add creates the field, making
/// that genre the primary.
public struct ReleaseGenreAddedEvent has copy, drop {
    release_id: ID,
    genre_id: ID,
}

/// Emitted when a genre is removed. Removing the last genre drops the field
/// and emits only this event.
public struct ReleaseGenreRemovedEvent has copy, drop {
    release_id: ID,
    genre_id: ID,
}

/// Emitted when an attached genre list is dropped by `clear_genres`.
public struct ReleaseGenresClearedEvent has copy, drop {
    release_id: ID,
}

// === Public Functions ===

/// Appends a genre to the release's list, creating the field on first use.
/// After cap authorization, aborts `EDuplicateGenre` if the genre is already
/// present, then `EMaxGenresExceeded` if the release is at capacity.
public fun add_genre(self: &mut Release, cap: &ReleaseAdminCap, genre: &Genre) {
    let release_id = object::id(self);
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
    emit(ReleaseGenreAddedEvent { release_id, genre_id });
}

/// Removes a genre by id; if it was the primary, the next genre becomes
/// primary. Removing the last genre drops the field. Aborts `ENoGenres` when
/// nothing is attached and `EGenreNotFound` when the genre is not assigned.
public fun remove_genre(self: &mut Release, cap: &ReleaseAdminCap, genre_id: ID) {
    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    assert!(df::exists(uid, ExtensionKey()), ENoGenres);
    let genres: &mut vector<ID> = df::borrow_mut(uid, ExtensionKey());
    let (found, index) = genres.index_of(&genre_id);
    assert!(found, EGenreNotFound);
    genres.remove(index);
    if (genres.is_empty()) {
        let _: vector<ID> = df::remove(uid, ExtensionKey());
    };
    emit(ReleaseGenreRemovedEvent { release_id, genre_id });
}

/// Removes the release's entire genre list. Authorizes first; an absent list
/// is a silent no-op.
public fun clear_genres(self: &mut Release, cap: &ReleaseAdminCap) {
    let release_id = object::id(self);
    let uid = self.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: vector<ID> = df::remove(uid, ExtensionKey());
        emit(ReleaseGenresClearedEvent { release_id });
    }
}

// === View Functions ===

/// Whether at least one genre is attached to this release.
public fun has_genres(self: &Release): bool {
    df::exists(self.uid(), ExtensionKey())
}

/// The release's genre ids in order, primary first. Aborts `ENoGenres` when
/// nothing is attached.
public fun genres(self: &Release): &vector<ID> {
    assert!(has_genres(self), ENoGenres);
    df::borrow(self.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun release_genre_added_fields(e: &ReleaseGenreAddedEvent): (ID, ID) {
    (e.release_id, e.genre_id)
}

#[test_only]
public fun release_genre_removed_fields(e: &ReleaseGenreRemovedEvent): (ID, ID) {
    (e.release_id, e.genre_id)
}

#[test_only]
public fun release_genres_cleared_fields(e: &ReleaseGenresClearedEvent): ID {
    e.release_id
}
