require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Mediateca lives on the LAN, and by default it is reached over plain HTTP:
  # there is no certificate to terminate, and forcing SSL would just redirect
  # every request into a scheme nothing answers on.
  #
  # Give the deploy a certificate (MEDIATECA_TLS_HOST — see config/deploy.yml) and
  # that flips. TLS then ends at kamal-proxy, which forwards plain HTTP inwards,
  # so Rails would go on believing the request was http:// and would write http://
  # into an https:// page — the <audio> src among them, which the browser refuses
  # as mixed content. The music would stop, and nothing would say why. So when
  # there is a certificate in front, Rails is told to assume it.
  #
  # force_ssl stays off even then: the proxy already sends http to https, and what
  # force_ssl would add on top is HSTS — a browser-side promise, remembered for a
  # year, that this name is https forever. On a house LAN, where the certificate
  # is homemade and may well be turned off again next month, that promise is a
  # trap and not a protection.
  config.assume_ssl = ENV["TLS_HOST"].present?
  config.force_ssl = false

  # Thruster sits in front and streams any file we name in this header, so the
  # FLACs never pass through Ruby — and it answers Range requests, so seeking
  # inside a track costs one partial read instead of a whole album.
  config.action_dispatch.x_sendfile_header = "X-Sendfile"

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
