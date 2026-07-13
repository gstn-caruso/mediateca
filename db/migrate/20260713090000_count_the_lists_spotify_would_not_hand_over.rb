class CountTheListsSpotifyWouldNotHandOver < ActiveRecord::Migration[8.1]
  def change
    # Spotify will not hand over every list it names — one made by somebody else,
    # one it has decided this app may not read. It answers 403 and it is entitled
    # to. Counted, so the page can say so rather than quietly coming home short.
    add_column :spotify_accounts, :refused_lists, :integer, null: false, default: 0
  end
end
