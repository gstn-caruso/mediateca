# What a hundred thousand scrobbles add up to, said out loud.
#
# And the three lists they are owed, which are made on demand rather than kept: a
# list that answers "what have you forgotten" is only true on the day it is asked.
class ReportsController < ApplicationController
  def show
    @report = Report.new(Current.profile)
  end

  # The one thing a library can do that a shop cannot: hand you a list of what it
  # does not have.
  def create
    made = Listening.new(Current.profile).make_the_lists

    redirect_to report_path, notice: made.any? ? "Made #{made.to_sentence(two_words_connector: ' and ')}." : "Nothing to make a list out of yet."
  end
end
