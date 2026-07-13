class ProfilesController < ApplicationController
  # The grid is the one page you can reach as nobody. Everything else needs a
  # listener — including, obviously, the page about one.
  skip_before_action :require_profile, only: [ :index, :create ]

  # The listener, gathered. Everything the app knows about somebody was scattered
  # across a menu, two connection pages and a shelf: what they have played, what it
  # says about them, what they have connected, and what they listen to and do not
  # own. It is one person; it should be one page.
  def show
    @taste = Statistics.new(Current.profile, span: "ever")
    @shelf = shelf
  end

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

  # The listener's shelf: whoever they play most, and — for each of them — the
  # records this house actually has, which is usually none of them. That second
  # half is the point. A shelf drawn only from the disk would be a picture of what
  # somebody owns, and this is a picture of what they listen to.
  def shelf
    standings = @taste.artists.first(14)
    ours = Artist.where(name: standings.map(&:name)).index_by(&:name)

    standings.map { |standing| [ standing, ours[standing.name] ] }
  end

  def profile_params
    params.expect(profile: [ :name ])
  end
end
