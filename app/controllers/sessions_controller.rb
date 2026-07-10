# Choosing a profile is starting a session; switching profiles is ending one.
# There is nothing else to it, which is why there is nothing else here.
class SessionsController < ApplicationController
  skip_before_action :require_profile

  def create
    profile = Profile.find_by(id: params[:profile_id])

    return redirect_to profiles_path unless profile

    cookies.signed.permanent[:profile_id] = { value: profile.id, httponly: true }
    redirect_to root_path
  end

  def destroy
    cookies.delete(:profile_id)
    redirect_to profiles_path
  end
end
