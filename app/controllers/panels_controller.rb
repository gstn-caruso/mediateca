# A hand let go of a panel's edge.
#
# It answers with nothing, on purpose. The panel is already the width the hand
# made it — the browser moved it while the hand was still moving, and it did not
# need this app's permission. Sending a page back would be sending back the page
# that is already on the screen, and it would cost a scroll and a history entry
# for the sin of resizing something. Nothing that isn't navigation navigates.
class PanelsController < ApplicationController
  def update
    return head :bad_request unless Panel.known?(params[:name]) && width

    Current.profile.widens(params[:name], to: width)

    head :no_content
  end

  private

  # A width off the network, which is to say a string somebody typed. It is a
  # width or it is nothing — and "wide-ish" is not a 500, it is a no.
  def width
    @width ||= Integer(params[:width], exception: false)
  end
end
