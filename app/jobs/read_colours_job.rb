# New music brings new sleeves, and a sleeve nobody has looked at is a record
# that plays in somebody else's colour.
class ReadColoursJob < ApplicationJob
  queue_as :default

  def perform
    Music::Colours.new.collect
  end
end
