# A heart. It hangs off whatever was liked, which so far is a track or an album.
class Like < ApplicationRecord
  belongs_to :profile
  belongs_to :likeable, polymorphic: true

  validates :profile_id, uniqueness: { scope: [ :likeable_type, :likeable_id ] }
end
