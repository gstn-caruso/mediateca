require "digest/md5"

module Lastfm
  # Last.fm takes nobody's word for a signed call. Every parameter is laid out in
  # order of name, run together with no separator at all, followed by the shared
  # secret, and hashed. Get any of that wrong and the only thing Last.fm ever says
  # back is that the signature is invalid.
  class Signature
    # Not part of the call, as far as the signature is concerned: `format` says
    # how we want the answer back, and `callback` is a JSONP nicety we never ask
    # for. Signing them is the classic way to be told the signature is invalid.
    UNSIGNED = %w[format callback api_sig].freeze

    def initialize(secret)
      @secret = secret
    end

    def for(params)
      Digest::MD5.hexdigest("#{run_together(params)}#{@secret}")
    end

    private

    # Sorted by the ASCII table, not the way people count. A batch of scrobbles
    # numbers its parameters, and there `artist[10]` comes before `artist[1]` —
    # sorting them as numbers would sign any batch of ten or more the wrong way.
    def run_together(params)
      params.reject { |name, _| UNSIGNED.include?(name.to_s) }
            .map { |name, value| [ name.to_s, value.to_s ] }
            .sort_by(&:first)
            .join
    end
  end
end
