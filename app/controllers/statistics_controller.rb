# What the history adds up to. A hundred thousand rows is not a fact anybody can
# read; who you actually listen to is.
class StatisticsController < ApplicationController
  def show
    @stats = Statistics.new(Current.profile, span: params[:span].to_s)
  end
end
