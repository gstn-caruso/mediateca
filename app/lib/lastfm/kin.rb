module Lastfm
  # Who is like whom, asked of Last.fm and kept only where it lands on a record
  # this house owns.
  #
  # That last part is the whole design. Last.fm will name a hundred bands like
  # Almafuerte and the rail can play exactly none of them — so what is written down
  # is the intersection: the artists on this disk that Last.fm says are kin. It
  # keeps the table small, the join trivial, and the rail honest about what it can
  # actually put on.
  class Kin
    A_DECENT_PAUSE = 1

    # Below this Last.fm is reaching, and a rail full of reaching is a rail nobody
    # trusts.
    CLOSE_ENOUGH = 0.1

    def initialize(pause: A_DECENT_PAUSE)
      @pause = pause
    end

    def find_them_all
      Artist.find_each do |artist|
        find_for(artist)
        sleep @pause
      end
    end

    def find_for(artist)
      kin = Lastfm.api.similar_artists(artist.name)
                  .select { it.fetch(:match) >= CLOSE_ENOUGH }
                  .filter_map { |band| [ ours[plainly(band.fetch(:name))], band.fetch(:match) ] }
                  .select(&:first)
                  .reject { |kin_id, _| kin_id == artist.id }

      remember(artist, kin)
    rescue Api::Unreachable
      # A NAS with no uplink still has a library. The rail falls back to the draw
      # it has always had, and the next sweep asks again.
      nil
    end

    private

    def remember(artist, kin)
      return if kin.empty?

      now = Time.current
      Kinship.upsert_all(
        kin.map { |kin_id, match| { artist_id: artist.id, kin_id:, match:, created_at: now, updated_at: now } },
        unique_by: %i[artist_id kin_id]
      )
    end

    # The same blunt match the import uses: case is nothing, accents are nothing.
    # Last.fm writes "Hermetica" as often as anybody writes "Hermética".
    def ours
      @ours ||= Artist.pluck(:id, :name).to_h { |id, name| [ plainly(name), id ] }
    end

    def plainly(name)
      I18n.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]+/, " ").strip
    end
  end
end
