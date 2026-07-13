# A Last.fm session key is a credential, and a permanent one: Last.fm gives it no
# expiry, and whoever holds it can scrobble to a real account and love and unlove
# songs on it forever. Mediateca has no passwords by design, but that is a bargain
# about a library on a home LAN — it was never a bargain about somebody's Last.fm.
#
# So it does not sit in the clear in a database file that gets copied to a backup
# drive. The keys are derived from SECRET_KEY_BASE, which the app already refuses
# to run in production without, so there is nothing new to deploy, rotate or lose.
Rails.application.configure do
  keys = Rails.application.key_generator

  config.active_record.encryption.primary_key = keys.generate_key("mediateca:encryption:primary", 32)
  config.active_record.encryption.deterministic_key = keys.generate_key("mediateca:encryption:deterministic", 32)
  config.active_record.encryption.key_derivation_salt = keys.generate_key("mediateca:encryption:salt", 32)
end
