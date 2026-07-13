# A life of listening, read back to the person who did it.
#
# The numbers are already all here — a hundred thousand rows of when, what and
# whether the house had a copy. What was missing was somebody willing to add them
# up and say the result out loud, which is the one thing a self-hosted library can
# do that no streaming service will: it has nothing to sell you, so it can afford
# to tell you what it does not have.
#
# Every figure below is one grouped query. There are a dozen of them and the table
# is large, so nothing here is asked twice.
class Report
  # The shelf on the profile page holds a dozen; a report can afford more.
  MANY = 25

  def initialize(profile)
    @profile = profile
  end

  def any? = plays.positive?

  def plays = @plays ||= @profile.plays.count
  def ours = @ours ||= @profile.plays.of_ours.count
  def elsewhere = plays - ours

  # The share of a life that is not on the disk. It is the number this whole app
  # exists to be honest about, and it is usually enormous.
  def missing_share
    return 0 if plays.zero?

    (elsewhere * 100.0 / plays).round
  end

  def since = @since ||= @profile.plays.minimum(:played_at)

  def years
    return 0 unless since

    ((Time.current - since) / 1.year).floor
  end

  def songs = @songs ||= @profile.absences.count + @profile.plays.of_ours.distinct.count(:track_id)
  def artists = @artists ||= by_artist.size

  # A bar for every year you have been listening. The shape of it is a life: the
  # year you discovered something, the year you were busy, the year you came back.
  def by_year
    @by_year ||= @profile.plays.group(Arel.sql("strftime('%Y', played_at)")).count.sort.to_h
  end

  # And the hours of a day. Everybody has a shape here and almost nobody knows what
  # theirs is — the small hours, the commute, the afternoon nobody was watching.
  def by_hour
    @by_hour ||= begin
      counted = @profile.plays.group(Arel.sql("CAST(strftime('%H', played_at) AS INTEGER)")).count

      (0..23).index_with { counted.fetch(it, 0) }
    end
  end

  def loudest_hour
    by_hour.max_by { it.last }&.first
  end

  # Everybody you play, with the records this house has by them — which for most of
  # them is none, and that is the point.
  def by_artist
    @by_artist ||= begin
      counted = @profile.plays
                        .left_joins(:absence, track: { album: :artist })
                        .group("COALESCE(artists.name, absences.artist)")
                        .order(Arel.sql("COUNT(plays.id) DESC"))
                        .limit(MANY)
                        .count("plays.id")
      shelved = Artist.where(name: counted.keys).index_by(&:name)

      counted.map { |name, plays| Line.new(name:, under: nil, plays:, artist: shelved[name]) }
    end
  end

  # The ones you play most and cannot play here. This is not a chart, it is a
  # shopping list — the records this house should have and does not.
  def wanted
    @wanted ||= @profile.plays
                        .joins(:absence)
                        .group("absences.artist")
                        .order(Arel.sql("COUNT(plays.id) DESC"))
                        .limit(MANY)
                        .count("plays.id")
                        .map { |name, plays| Line.new(name:, under: nil, plays:, artist: nil) }
  end

  def wanted_songs
    @wanted_songs ||= @profile.plays
                              .joins(:absence)
                              .group("absences.title", "absences.artist")
                              .order(Arel.sql("COUNT(plays.id) DESC"))
                              .limit(MANY)
                              .count("plays.id")
                              .map { |(title, artist), plays| Line.new(name: title, under: artist, plays:, artist: nil) }
  end

  # And what you *can* play: the records on the disk, worn out.
  def worn_out
    @worn_out ||= begin
      counted = @profile.plays.joins(track: :album)
                        .group("albums.id")
                        .order(Arel.sql("COUNT(plays.id) DESC"))
                        .limit(12)
                        .count("plays.id")
      found = Album.where(id: counted.keys).includes(:artist).index_by(&:id)

      counted.filter_map do |id, plays|
        album = found[id]
        Line.new(name: album.title, under: album.artist.name, plays:, artist: album) if album
      end
    end
  end

  # One line of anything: what it is, who it is by, how many times, and the thing on
  # the disk it points at — when there is one, which is the whole question.
  Line = Data.define(:name, :under, :plays, :artist)
end
