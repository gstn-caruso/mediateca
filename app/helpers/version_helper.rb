module VersionHelper
  # Settled once at boot; the rail asks for it on every page.
  def app_version
    @app_version ||= Version.new(Rails.configuration.x.version_name)
  end
end
