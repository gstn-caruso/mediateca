# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_13_031911) do
  create_table "albums", force: :cascade do |t|
    t.string "accent"
    t.string "album_type"
    t.integer "artist_id", null: false
    t.string "cover_path"
    t.datetime "created_at", null: false
    t.string "directory", null: false
    t.integer "disc_total", default: 1, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "year"
    t.index ["artist_id"], name: "index_albums_on_artist_id"
    t.index ["directory"], name: "index_albums_on_directory", unique: true
  end

  create_table "artists", force: :cascade do |t|
    t.string "accent"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "portrait_credit"
    t.string "portrait_path"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_artists_on_name", unique: true
  end

  create_table "likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "likeable_id", null: false
    t.string "likeable_type", null: false
    t.integer "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["likeable_type", "likeable_id"], name: "index_likes_on_likeable"
    t.index ["profile_id", "likeable_type", "likeable_id"], name: "index_likes_on_profile_and_likeable", unique: true
    t.index ["profile_id"], name: "index_likes_on_profile_id"
  end

  create_table "playlist_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "playlist_id", null: false
    t.integer "position", null: false
    t.integer "track_id", null: false
    t.datetime "updated_at", null: false
    t.index ["playlist_id", "position"], name: "index_playlist_entries_on_playlist_id_and_position", unique: true
    t.index ["playlist_id"], name: "index_playlist_entries_on_playlist_id"
    t.index ["track_id"], name: "index_playlist_entries_on_track_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "profile_id", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id", "name"], name: "index_playlists_on_profile_id_and_name", unique: true
    t.index ["profile_id"], name: "index_playlists_on_profile_id"
  end

  create_table "plays", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "profile_id", null: false
    t.integer "track_id", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_plays_on_profile_id"
    t.index ["track_id"], name: "index_plays_on_track_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_profiles_on_name", unique: true
  end

  create_table "standings", force: :cascade do |t|
    t.integer "artist_id", null: false
    t.datetime "created_at", null: false
    t.integer "profile_id", null: false
    t.string "standing", null: false
    t.datetime "updated_at", null: false
    t.index ["artist_id"], name: "index_standings_on_artist_id"
    t.index ["profile_id", "artist_id"], name: "index_standings_on_profile_id_and_artist_id", unique: true
    t.index ["profile_id"], name: "index_standings_on_profile_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.integer "album_id", null: false
    t.string "artist"
    t.integer "bit_depth"
    t.integer "bit_rate"
    t.string "bit_rate_mode"
    t.string "codec"
    t.datetime "created_at", null: false
    t.integer "disc_no", default: 1, null: false
    t.float "duration"
    t.string "path", null: false
    t.integer "sample_rate"
    t.string "title", null: false
    t.integer "track_no"
    t.datetime "updated_at", null: false
    t.index ["album_id", "disc_no", "track_no"], name: "index_tracks_on_album_id_and_disc_no_and_track_no"
    t.index ["album_id"], name: "index_tracks_on_album_id"
    t.index ["path"], name: "index_tracks_on_path", unique: true
  end

  add_foreign_key "albums", "artists"
  add_foreign_key "likes", "profiles"
  add_foreign_key "playlist_entries", "playlists"
  add_foreign_key "playlist_entries", "tracks"
  add_foreign_key "playlists", "profiles"
  add_foreign_key "plays", "profiles"
  add_foreign_key "plays", "tracks"
  add_foreign_key "standings", "artists"
  add_foreign_key "standings", "profiles"
  add_foreign_key "tracks", "albums"
end
