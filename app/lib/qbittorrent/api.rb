require "net/http"

module Qbittorrent
  # The house's torrent client, asked to go and find the records the house is
  # missing.
  #
  # Everything here is a fact learned the hard way and written down so it is not
  # learned twice. They are all in the comments, because every one of them fails in
  # silence: a search that returns nothing at all looks exactly like a search that
  # found nothing.
  class Api
    Unreachable = Class.new(StandardError)

    # A search takes a moment to go out to twenty indexers and come back.
    PATIENCE = 25
    A_BEAT = 1.5

    # It answers every query with scientific datasets, which then win the ranking on
    # seeders. Two thousand results and not one of them music.
    NOISE = %w[academictorrents].freeze

    # A FLAC that weighs what an MP3 weighs is an MP3 that has been told it is a
    # FLAC. A record is bigger than this.
    A_REAL_RECORD = 150 * 1024 * 1024

    # Lossless, said the several ways the world says it.
    LOSSLESS = /\b(flac|lossless|ape|wavpack|24[\s\-]?bit|24[\s\-]?96|vinyl[\s\-]?rip)\b/i

    def configured?
      Rails.configuration.x.qbittorrent.present?
    end

    def version
      get("/app/version").body
    end

    # Lossless only, noise excluded, and one row per torrent however many indexers
    # list it — the same release comes back five or six times, once per site.
    # The wait is a local, not a field. Held on the client it would carry over from
    # one search to the next — so the first record of a sweep would be waited for
    # properly and the two behind it would be given no time at all, come back empty,
    # and be written off as unseeded. Silently, and only ever from the second one on.
    def search(query)
      job = start(query)
      waited = 0

      until finished?(job) || waited > PATIENCE
        sleep A_BEAT
        waited += A_BEAT
      end

      lossless(results(job))
    ensure
      stop(job) if job
    end

    # Straight into the music tree, under a directory of its own — because the scan
    # reads a record as "the directory two levels below the root", and a torrent
    # dumped flat at the top would be read as an artist with no records. Given
    # somewhere to land, it lands where the library already looks.
    #
    # It does not land there until it is finished: qBittorrent is set to write
    # partial downloads somewhere else entirely, and a scan that met a half-written
    # FLAC would file half a record.
    def add(magnet, into:, as: "mediateca")
      post("/torrents/add", urls: magnet, category: as, savepath: into)
    end

    # What is on the way, by infohash, so a record can say how far along it is.
    def progress(hashes)
      return {} if hashes.empty?

      JSON.parse(get("/torrents/info", hashes: hashes.join("|")).body)
          .to_h { |it| [ it["hash"], { progress: (it["progress"].to_f * 100).round, state: it["state"], name: it["name"] } ] }
    end

    private

    def start(query)
      # `all`, never `music`: twelve of the twenty plugins declare only the `all`
      # category, and asking for `music` quietly leaves them out — including the
      # three that actually deliver. Lossless is filtered by name, afterwards.
      JSON.parse(post("/search/start", pattern: query, plugins: "enabled", category: "all").body).fetch("id")
    end

    def finished?(job)
      JSON.parse(get("/search/status", id: job).body).first&.fetch("status") == "Stopped"
    end

    def results(job)
      JSON.parse(get("/search/results", id: job).body).fetch("results")
    end

    def stop(job)
      post("/search/stop", id: job)
    rescue Unreachable
      nil
    end

    def lossless(results)
      results
        .reject { NOISE.include?(it["siteUrl"].to_s[%r{//(?:www\.)?([^./]+)}, 1]) }
        .select { it["fileName"].to_s.match?(LOSSLESS) }
        .select { it["fileSize"].to_i >= A_REAL_RECORD }
        .group_by { infohash(it["fileUrl"]) }
        .filter_map { |hash, all| found(hash, all) if hash }
        .sort_by { -it.fetch(:seeders) }
    end

    def found(hash, all)
      best = all.max_by { it["nbSeeders"].to_i }

      { hash:, name: best["fileName"], magnet: best["fileUrl"],
        seeders: best["nbSeeders"].to_i, bytes: best["fileSize"].to_i, listed_by: all.size }
    end

    def infohash(magnet)
      magnet.to_s[/xt=urn:btih:([a-zA-Z0-9]+)/, 1]&.downcase
    end

    def get(path, **params)
      uri = URI.parse("#{Rails.configuration.x.qbittorrent}/api/v2#{path}")
      uri.query = URI.encode_www_form(params) if params.any?

      answered(Net::HTTP.get_response(uri, cookie))
    end

    def post(path, **form)
      uri = URI.parse("#{Rails.configuration.x.qbittorrent}/api/v2#{path}")
      asking = Net::HTTP::Post.new(uri, cookie)
      asking.set_form_data(form.compact)

      answered(Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") { it.request(asking) })
    end

    def answered(response)
      raise Unreachable, "qBittorrent answered #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      remember(response)
      response
    rescue SystemCallError, SocketError, Net::OpenTimeout, Net::ReadTimeout, JSON::ParserError => e
      raise Unreachable, "qBittorrent: #{e.message}"
    end

    # A search job belongs to the HTTP session that started it. Ask for its status
    # on a fresh connection and qBittorrent 404s the job — it is not gone, we are a
    # stranger — and the engine looks broken when it is merely being asked by
    # somebody it has never met. So the cookie is kept for the life of the search.
    #
    # Whatever it is called. It is not `SID`: qBittorrent names it for the port it
    # is listening on, `QBT_SID_8079`, and a client looking for `SID=` keeps nothing
    # at all and never notices.
    def remember(response)
      @sid ||= response.get_fields("set-cookie")&.first&.split(";")&.first
    end

    def cookie
      @sid ? { "Cookie" => @sid } : {}
    end
  end
end
