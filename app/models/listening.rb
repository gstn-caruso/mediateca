# Three lists a hundred thousand scrobbles are owed, and that nobody could have
# made by hand.
#
# They are made from the history rather than from the disk, which is what makes
# them worth having: the disk knows what you own and can only ever sort it, and the
# history knows what you *played* — including, and especially, the things you
# played that are not here at all.
class Listening
  MANY = 60

  # A song you have not gone back to in a year is a song you have forgotten, and
  # forgetting is the thing a library of your own records is supposed to prevent.
  A_WHILE = 1.year

  def initialize(profile)
    @profile = profile
  end

  # Names are what a listener sees, so they are the whole of the interface here.
  # Rebuilt each time rather than added to: these are not lists somebody made, they
  # are answers to a question, and an answer that keeps yesterday's songs in it is
  # a stale answer wearing a fresh name.
  def make_the_lists
    [
      fill("On repeat", most_played),
      fill("Not on the disk", never_here),
      fill("You've forgotten these", forgotten)
    ].compact
  end

  private

  # What you play most, of what you have. The one list any music app could make —
  # and the only one of these three that it could.
  def most_played
    @profile.plays.of_ours
            .group(:track_id).order(Arel.sql("COUNT(plays.id) DESC")).limit(MANY)
            .count("plays.id").keys
            .map { { track_id: it, absence_id: nil } }
  end

  # What you play most and cannot play here. It is a playlist that plays nothing,
  # and it is the most useful one in the app: it is exactly what to go and find.
  def never_here
    @profile.plays.joins(:absence)
            .group(:absence_id).order(Arel.sql("COUNT(plays.id) DESC")).limit(MANY)
            .count("plays.id").keys
            .map { { track_id: nil, absence_id: it } }
  end

  # Songs on the disk that you used to play and have not been back to in a year.
  # Nothing that sells music has any reason to build this: it points you at what
  # you already own.
  def forgotten
    lately = @profile.plays.of_ours.where(played_at: A_WHILE.ago..).select(:track_id)

    @profile.plays.of_ours
            .where.not(track_id: lately)
            .group(:track_id).order(Arel.sql("COUNT(plays.id) DESC")).limit(MANY)
            .count("plays.id").keys
            .map { { track_id: it, absence_id: nil } }
  end

  def fill(name, lines)
    return nil if lines.empty?

    list = @profile.playlists.find_or_create_by!(name:)
    list.entries.destroy_all

    now = Time.current
    PlaylistEntry.insert_all(
      lines.each_with_index.map { |line, at| line.merge(playlist_id: list.id, position: at + 1, created_at: now, updated_at: now) }
    )

    list
  end
end
