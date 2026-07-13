require "test_helper"

module Lastfm
  # Last.fm takes nobody's word for a signed call. Get the recipe wrong and the
  # only thing it ever says back is that the signature is invalid, which is a
  # miserable thing to debug — so the recipe is pinned here, against the example
  # Last.fm itself publishes.
  class SignatureTest < ActiveSupport::TestCase
    # Verbatim from https://www.last.fm/api/authspec — including the secret,
    # which is theirs and is a joke about Cher.
    test "the signature Last.fm's own documentation gives" do
      signed = Signature.new("ilovecher").for(method: "auth.getSession", api_key: "xxxxxxxxxx", token: "yyyyyy")

      assert_equal Digest::MD5.hexdigest("api_keyxxxxxxxxxxmethodauth.getSessiontokenyyyyyyilovecher"), signed
    end

    # The parameters are laid out in order of name, whatever order they arrived
    # in, so the same call always signs the same way.
    test "the order the parameters arrive in is not the order they are signed in" do
      signature = Signature.new("ilovecher")

      assert_equal signature.for(a: 1, b: 2), signature.for(b: 2, a: 1)
    end

    # A batch of scrobbles numbers its parameters, and Last.fm sorts those names
    # by the ASCII table rather than by the number inside them: `artist[10]` comes
    # before `artist[1]`, because `0` comes before `1`. Sorting them the way
    # people count would sign a batch of ten or more scrobbles wrong — and Last.fm
    # would only say the signature was invalid.
    test "ten scrobbles sort before two, because that is how Last.fm reads them" do
      signed = Signature.new("s").for("artist[1]" => "a", "artist[10]" => "j", "artist[2]" => "b")

      assert_equal Digest::MD5.hexdigest("artist[10]jartist[1]aartist[2]bs"), signed
    end

    # Neither is part of the call as far as the signature is concerned: `format`
    # says how we want the answer back, `callback` is a JSONP nicety we never ask
    # for. Signing them is the classic way to be told the signature is invalid.
    test "format and callback are not signed" do
      signature = Signature.new("ilovecher")

      assert_equal signature.for(method: "track.love"),
                   signature.for(method: "track.love", format: "json", callback: "whatever")
    end
  end
end
