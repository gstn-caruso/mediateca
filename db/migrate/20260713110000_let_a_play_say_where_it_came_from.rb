class LetAPlaySayWhereItCameFrom < ActiveRecord::Migration[8.1]
  def up
    # Where this listening was heard. Everything already in the table happened
    # here, in this app, because until now there was nowhere else it could have.
    #
    # It matters for more than a label. Last.fm hands over a listener's whole
    # history and those become plays — so a catch-up that could not tell a play
    # heard here from one Last.fm told us about would hand Last.fm back its own
    # history, a hundred thousand songs of it, as though it were new listening.
    add_column :plays, :source, :string, null: false, default: "mediateca"
    add_index :plays, [ :profile_id, :source ]

    # A play used to be a play of a record you own, because there was no way to
    # say anything else. But most of what anybody has ever listened to is not on
    # their disk, and a history that quietly dropped all of it would be a history
    # of the wrong life.
    change_column_null :plays, :track_id, true
    add_reference :plays, :absence, null: true, foreign_key: true

    # SQLite counts two NULLs as different, so the index that keeps one listen from
    # being written twice does not cover the songs nobody owns. This one does.
    add_index :plays, [ :profile_id, :absence_id, :played_at ], unique: true
  end

  def down
    remove_index :plays, [ :profile_id, :absence_id, :played_at ]
    remove_reference :plays, :absence
    change_column_null :plays, :track_id, false
    remove_index :plays, [ :profile_id, :source ]
    remove_column :plays, :source
  end
end
