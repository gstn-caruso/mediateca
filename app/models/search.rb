# Searching a home library is not searching the web. A thousand tracks fit in a
# LIKE scan that finishes before the page paints, and an FTS index would be a
# second copy of the truth to keep in step with the disk.
class Search
  # SQLite reads a backslash as a backslash unless the LIKE says otherwise, so
  # escaping the wildcard is only half of it: the escape character has to be
  # declared too.
  ESCAPE = "\\".freeze

  # A search is for finding something, not for reading the library out. Nobody
  # scrolls the six hundredth song that has an "a" in it — but the page would
  # render all six hundred, and clicking one would queue all six hundred.
  MOST = 50

  def initialize(term)
    @term = term.to_s.strip
  end

  # Each scan is run once and kept. The page asks whether there are any results
  # and then asks for them, and the same LIKE over the same table twice is one
  # scan too many.
  def artists
    @artists ||= matching(Artist.ordered, :name)
  end

  def albums
    @albums ||= matching(Album.ordered.includes(:artist), :title)
  end

  def tracks
    @tracks ||= matching(Track.ordered.includes(album: :artist), :title)
  end

  def blank?
    @term.blank?
  end

  def any?
    !blank? && [ artists, albums, tracks ].any?(&:any?)
  end

  private

  # Asking for nothing is not asking for everything.
  #
  # And % and _ are wildcards in LIKE: somebody who types one means the
  # character, so it is escaped rather than obeyed.
  def matching(scope, column)
    return [] if blank?

    pattern = "%#{ApplicationRecord.sanitize_sql_like(@term)}%"

    scope.where(scope.arel_table[column].matches(pattern, ESCAPE)).limit(MOST).to_a
  end
end
