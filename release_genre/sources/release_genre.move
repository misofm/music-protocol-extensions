// Copyright (c) Miso Labs, Inc.
// SPDX-License-Identifier: FSL-1.1-ALv2

module release_genre::release_genre;

// === Imports ===

use sui::dynamic_field as df;
use sui::event::emit;
use genre::genre::Genre;
use miso_music::release::{Release, ReleaseAdminCap};

// === Errors ===

const EDuplicateGenre: u64 = 0;
const EMaxGenresExceeded: u64 = 1;
const ENoGenres: u64 = 2;
const EGenreNotFound: u64 = 3;

// === Constants ===

const MAX_GENRES: u64 = 6;

// === Structs ===

public struct ExtensionKey() has copy, drop, store;

// === Events ===

public struct ReleaseGenreAddedEvent has copy, drop {
    release_id: ID,
    genre_id: ID,
}

public struct ReleaseGenreRemovedEvent has copy, drop {
    release_id: ID,
    genre_id: ID,
}

public struct ReleaseGenresClearedEvent has copy, drop {
    release_id: ID,
}

// === Public Functions ===

public fun add_genre(release: &mut Release, cap: &ReleaseAdminCap, genre: &Genre) {
    let release_id = object::id(release);
    let genre_id = object::id(genre);
    let uid = release.uid_mut(cap);
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

public fun remove_genre(release: &mut Release, cap: &ReleaseAdminCap, genre_id: ID) {
    let release_id = object::id(release);
    let uid = release.uid_mut(cap);
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

public fun clear_genres(release: &mut Release, cap: &ReleaseAdminCap) {
    let release_id = object::id(release);
    let uid = release.uid_mut(cap);
    if (df::exists(uid, ExtensionKey())) {
        let _: vector<ID> = df::remove(uid, ExtensionKey());
        emit(ReleaseGenresClearedEvent { release_id });
    }
}

// === View Functions ===

public fun has_genres(release: &Release): bool {
    df::exists(release.uid(), ExtensionKey())
}

public fun genres(release: &Release): &vector<ID> {
    assert!(has_genres(release), ENoGenres);
    df::borrow(release.uid(), ExtensionKey())
}

// === Test Functions ===

#[test_only]
public fun release_genre_added_fields(event: &ReleaseGenreAddedEvent): (ID, ID) {
    (event.release_id, event.genre_id)
}

#[test_only]
public fun release_genre_removed_fields(event: &ReleaseGenreRemovedEvent): (ID, ID) {
    (event.release_id, event.genre_id)
}

#[test_only]
public fun release_genres_cleared_fields(event: &ReleaseGenresClearedEvent): ID {
    event.release_id
}
