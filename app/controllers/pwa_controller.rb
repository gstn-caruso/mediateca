# What turns a tab into an app: the manifest Safari reads when you say Add to
# Dock — and Chrome before it offers to install — and the worker that answers
# when the server does not.
#
# Both are fetched before anybody has picked a name off the grid: the browser
# asks for them on its way to the profile picker. Neither may insist on a
# listener, and neither says anything about one.
class PwaController < ApplicationController
  skip_before_action :require_profile

  # Rails refuses to serve a JavaScript response to a plain GET — it assumes a
  # <script> tag on somebody else's site is trying to read yours, and answers 422
  # (ActionController::InvalidCrossOriginRequest). A service worker is fetched by
  # exactly that kind of request, so without this the worker never installs. The
  # guard is protecting nothing here: this script is the same for everyone, and
  # it is asked for before anybody has said who they are.
  skip_forgery_protection

  # The content types are the reason this is a controller and not two files in
  # public/. A manifest is spec'd as application/manifest+json; a worker served
  # as anything but JavaScript is refused on the MIME type alone, and the app
  # quietly stays a tab forever.
  def manifest
    render template: "pwa/manifest", formats: :json, content_type: "application/manifest+json"
  end

  def service_worker
    render template: "pwa/service-worker", formats: :js, content_type: "text/javascript"
  end
end
