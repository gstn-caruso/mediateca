require "test_helper"

# An artist wears the colour of their photograph — so the photograph has to be
# there before there is anything to read. A scan reads the colours of everything
# it knows about, and then goes looking for faces: every face it finds lands
# after the reading is over, and its owner would stand there colourless until the
# next scan of the library. So whoever brings the faces asks for them to be read.
class FetchPortraitsJobTest < ActiveJob::TestCase
  test "a face that has just landed is sent to have its colour read" do
    assert_enqueued_with(job: ReadColoursJob) { FetchPortraitsJob.perform_now }
  end
end
