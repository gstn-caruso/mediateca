class ProfilesController < ApplicationController
  # The one page you can reach as nobody. Everything else needs a listener.
  skip_before_action :require_profile

  def index
    @profiles = Profile.ordered
    @profile = Profile.new
  end

  def create
    @profile = Profile.new(profile_params)

    return redirect_to profiles_path if @profile.save

    @profiles = Profile.ordered
    render :index, status: :unprocessable_content
  end

  private

  def profile_params
    params.expect(profile: [ :name ])
  end
end
