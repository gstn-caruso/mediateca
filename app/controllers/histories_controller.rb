# Everything this listener ever heard, in the order they heard it.
#
# The library is a shelf and says what you own. This is the other thing a record
# collection quietly keeps — and the app kept it all along, fed the counters and
# the suggestions with it, and never once showed it to anybody.
#
# A life of it is a hundred thousand rows, so it is read a page at a time. Not by
# offset, which asks the database to count past everything it is not going to
# show: by the clock, which is what the page is ordered by anyway.
class HistoriesController < ApplicationController
  A_PAGE = 100

  def show
    @history = Current.profile.history(before: before, limit: A_PAGE + 1)
    @more = @history.size > A_PAGE
    @history = @history.first(A_PAGE)
  end

  private

  def before
    Time.zone.at(Integer(params[:before], exception: false) || Time.current.to_i + 1)
  end
end
