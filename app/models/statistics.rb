# What a history adds up to.
#
# A hundred and twenty-seven thousand rows is not a fact anybody can read. Who you
# actually listen to is — and it is a question a library of your own records is
# uniquely able to answer, because no shop is guessing here and nothing is being
# sold.
#
# It counts across the whole history: the records on the disk and the songs that
# are not. Leaving the second out would be the easy mistake, and it would put
# whatever you happen to *own* at the top of a chart about what you *play*.
class Statistics
  # What a listener means by "lately", and what they mean by "ever".
  SPANS = {
    "month" => [ "This month", 1.month ],
    "year" => [ "This year", 1.year ],
    "ever" => [ "All time", nil ]
  }.freeze

  A_FEW = 20

  # One line of a chart: what it is, who it is by, how many times — and the record
  # it is off, when this house has one to point at.
  Standing = Data.define(:name, :under, :plays, :album)

  def initialize(profile, span: "year")
    @profile = profile
    @span = SPANS.key?(span.to_s) ? span.to_s : "year"
  end

  attr_reader :span

  def title = SPANS.fetch(@span).first

  def any? = within.exists?

  def songs
    @songs ||= chart_of("COALESCE(tracks.title, absences.title)", "COALESCE(artists.name, absences.artist)")
  end

  def artists
    @artists ||= chart_of("COALESCE(artists.name, absences.artist)")
  end

  # Records only. A song you do not own is off no record this house has ever seen:
  # Last.fm names the sleeve it came from, but a name is not a record, and a chart
  # of records you cannot put on is not a chart anybody wants.
  def records
    @records ||= begin
      counted = ours.group("albums.id").order(Arel.sql("COUNT(plays.id) DESC")).limit(A_FEW).count("plays.id")
      found = Album.where(id: counted.keys).includes(:artist).index_by(&:id)

      counted.filter_map do |id, plays|
        album = found[id]
        Standing.new(name: album.title, under: album.artist.name, plays:, album:) if album
      end
    end
  end

  private

  # Every play in the span, joined to whichever of the two things it is a play of.
  # Left joins, both of them: an inner join to tracks would silently throw away
  # every song nobody owns, which is the one thing this must not do.
  def within
    scope = @profile.plays.left_joins(:absence, track: { album: :artist })
    since = SPANS.fetch(@span).last

    since ? scope.where(played_at: since.ago..) : scope
  end

  def ours
    within.where.not(tracks: { id: nil })
  end

  def chart_of(name, under = nil)
    within.group(*[ name, under ].compact)
          .order(Arel.sql("COUNT(plays.id) DESC"))
          .limit(A_FEW)
          .count("plays.id")
          .map { |key, plays| Standing.new(name: Array(key).first, under: Array(key).second, plays:, album: nil) }
  end
end
