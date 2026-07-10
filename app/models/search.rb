# Searching a home library is not searching the web. A thousand tracks fit in a
# LIKE scan that finishes before the page paints, and an FTS index would be a
# second copy of the truth to keep in step with the disk.
class Search
  def initialize(term)
    @term = term.to_s.strip
  end

  def artists
    matching Artist.ordered, :name
  end

  def albums
    matching Album.ordered.includes(:artist), :title
  end

  def tracks
    matching Track.includes(album: :artist), :title
  end

  def blank?
    @term.blank?
  end

  def any?
    !blank? && [ artists, albums, tracks ].any?(&:exists?)
  end

  private

  # Asking for nothing is not asking for everything.
  #
  # And % and _ are wildcards in LIKE: somebody who types one means the
  # character, so it is escaped rather than obeyed.
  def matching(scope, column)
    return scope.none if blank?

    scope.where("#{column} LIKE ?", "%#{ApplicationRecord.sanitize_sql_like(@term)}%")
  end
end
