# Hands a file on disk to the client without reading it through Ruby.
#
# In production `x_sendfile_header` is set: send_file only names the file and
# Thruster streams it, honouring Range on its own. With nothing in front —
# development, tests — Rails has to serve the bytes itself, and send_file alone
# answers 200 with the whole file. A music player needs Range to seek, and a
# listener should not wait for 80MB of FLAC to reach the second minute, so we
# let Rack::Files do it: it already implements Range, If-Range and 416.
module ServesMedia
  extend ActiveSupport::Concern

  included do
    rescue_from MediaFile::Forbidden, with: :refuse_to_serve
  end

  private

  # Portraits live under storage/, not under the media root, because the music
  # is mounted read-only. A different root, but still a root.
  def serve(path, as:, root: MediaFile.root)
    return head :not_found if path.blank?

    file = MediaFile.new(path, root:)
    return head :not_found unless file.exist?

    if front_end_serves_files?
      send_file file.path, type: as, disposition: "inline"
    else
      serve_with_ranges(file, as:)
    end
  end

  # Whoever serves the file also serves the range.
  def front_end_serves_files?
    Rails.application.config.action_dispatch.x_sendfile_header.present?
  end

  def serve_with_ranges(file, as:)
    status, headers, body = Rack::Files.new(File.dirname(file.path)).serving(request, file.path)

    self.status = status
    headers.each { |name, value| response.headers[name] = value }
    response.headers["content-type"] = as
    # Rack::Files answers ranges but never advertises that it does, and an
    # <audio> element only offers a seek bar to a server that says so.
    response.headers["accept-ranges"] = "bytes"
    self.response_body = body
  end

  def refuse_to_serve
    head :forbidden
  end
end
