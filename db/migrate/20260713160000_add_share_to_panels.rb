class AddShareToPanels < ActiveRecord::Migration[8.1]
  def change
    # What this panel takes of a room with no content in it.
    #
    # A width is in pixels and has two ends: under 240 a rail cannot say what it is
    # for, and over 480 it has stopped standing beside the content and started
    # being it. Neither is true of a panel with no content to stand beside. It is
    # not a rail then — it is half of an empty room, and half of a room is nowhere
    # near 480 pixels.
    #
    # So this is not a width. A share says nothing on its own: it says only how
    # this panel stands to the ones beside it, so 300 against 100 divides any room
    # three to one — on a laptop, or on a kitchen tablet where 700 pixels is the
    # whole of it. It rides on the same row as the width because a panel is one
    # thing that is asked two questions, not two things.
    #
    # Nullable, because the ordinary case is that nobody has ever divided an empty
    # room. Then it is divided in the proportion the panels are kept at, which for
    # a listener who has touched nothing is panels of a size.
    add_column :panels, :share, :float
  end
end
