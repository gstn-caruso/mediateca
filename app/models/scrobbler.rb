# The Last.fm a listener has connected: who they are there, and the key that lets
# this app act as them.
#
# The key is encrypted, and it is worth saying why in a house with no passwords.
# The bargain in SECURITY.md is about a music library on a home LAN — anybody who
# can reach it can be anybody. It was never a bargain about somebody's Last.fm
# account, and a session key Last.fm never expires is not a thing to leave lying
# in a database file that gets backed up.
class Scrobbler < ApplicationRecord
  belongs_to :profile

  encrypts :session_key

  validates :username, presence: true
  validates :session_key, presence: true

  # Last.fm's own page for this listener. Its terms ask that a profile we show
  # links back to the profile it came from.
  def url
    "https://www.last.fm/user/#{CGI.escape(username)}"
  end
end
