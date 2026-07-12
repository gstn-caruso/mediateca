# Which build is answering right now.
#
# Asked by a tab on its way back from a deploy: the container that held its
# socket is the one that was replaced, so it comes back not knowing whether the
# app underneath it changed. This is how it finds out. See deploy_controller.js.
class BuildsController < ApplicationController
  # A deploy can take the session with it, and a tab still has to be able to ask
  # what it is looking at. The answer names a build; it says nothing about anyone.
  skip_before_action :require_profile

  def show
    render plain: Rails.configuration.x.build
  end
end
