class SearchesController < ApplicationController
  def show
    @search = Search.new(params[:q])
  end
end
