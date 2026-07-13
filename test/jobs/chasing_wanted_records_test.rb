require "test_helper"

# It fires on its own, and the reason it can be trusted to is that it walks.
class ChasingWantedRecordsTest < ActiveJob::TestCase
  setup do
    Lastfm.api = FakeLastfm.new
    Qbittorrent.api = @qbit = FakeQbittorrent.new
    @gaston = Profile.create!(name: "Gastón")
    @gaston.scrobbles_to(username: "ekvintroj", session_key: "k")
  end

  # The scan reads a record as the directory two levels under the root, so that is
  # where it is put — the shelf it would have stood on all along. A torrent dumped
  # flat at the top would be read as an artist with no records.
  test "a record lands on the shelf it would have stood on" do
    Rails.configuration.x.qbittorrent_into = "/music"
    want("Nirvana", "In Utero", plays: 793)
    @qbit.seeding("Nirvana In Utero", edition("In Utero [FLAC]", seeders: 90))

    ChaseWantedRecordsJob.perform_now

    assert_equal "/music/Nirvana/In Utero", @qbit.added.sole.fetch(:into)
  end

  test "the record you play most and do not own is fetched" do
    want("Nirvana", "In Utero", plays: 793)
    @qbit.seeding("Nirvana In Utero", edition("Nirvana - In Utero [FLAC]", seeders: 90))

    ChaseWantedRecordsJob.perform_now

    assert_equal "magnet:Nirvana - In Utero [FLAC]", @qbit.added.sole.fetch(:magnet)
    assert_predicate WantedRecord.sole, :on_the_way?
  end

  # A search that turns up an original, a deluxe, a remaster and a vinyl rip has not
  # answered the question — it has asked one, and a machine has no business guessing
  # which edition somebody meant.
  test "four plausible editions is a question, not an answer" do
    want("Nirvana", "In Utero", plays: 793)
    @qbit.seeding("Nirvana In Utero",
                  edition("In Utero [FLAC]", seeders: 90),
                  edition("In Utero — 20th Anniversary Deluxe [FLAC]", seeders: 70))

    ChaseWantedRecordsJob.perform_now

    assert_empty @qbit.added, "nobody knows which one you meant, so nothing is taken"
    assert_predicate WantedRecord.sole, :sought?
    assert_match(/editions/, WantedRecord.sole.nothing_doing)
  end

  test "a record nobody is seeding says so, rather than saying nothing" do
    want("Nirvana", "In Utero", plays: 793)

    ChaseWantedRecordsJob.perform_now

    assert_match(/lossless/i, WantedRecord.sole.nothing_doing)
  end

  # A record nobody could find is not a record to go looking for every half hour
  # forever.
  test "a record is sought once" do
    want("Nirvana", "In Utero", plays: 793)
    ChaseWantedRecordsJob.perform_now

    ChaseWantedRecordsJob.perform_now

    assert_equal 1, @qbit.searched.size
  end

  # The leash. The want list is thousands long and would be a hundred gigabytes.
  test "it takes three at a time, heaviest want first" do
    5.times { |at| want("Band #{at}", "Record #{at}", plays: 100 + at) }

    ChaseWantedRecordsJob.perform_now

    assert_equal 3, @qbit.searched.size
    assert_equal "Band 4 Record 4", @qbit.searched.first
  end

  test "a torrent client nobody can reach leaves the record unsought" do
    want("Nirvana", "In Utero", plays: 793)
    Qbittorrent.api = FakeQbittorrent::Unreachable.new

    assert_nothing_raised { ChaseWantedRecordsJob.perform_now }

    assert_not_predicate WantedRecord.sole, :sought?, "and the next sweep tries again"
  end

  test "no torrent client, no chasing" do
    want("Nirvana", "In Utero", plays: 793)
    Qbittorrent.api = FakeQbittorrent.new(configured: false)

    ChaseWantedRecordsJob.perform_now

    assert_not_predicate WantedRecord.sole, :sought?
  end

  # The clock on the library page, and the loop closing: what arrives stops being a
  # want, and the scan is what turns it into a record.
  test "a record that finished downloading is no longer on the way" do
    want("Nirvana", "In Utero", plays: 793)
    WantedRecord.sole.sought(hash: "abc", name: "In Utero")
    @qbit.going("abc", 100)

    assert_enqueued_with job: ScanMusicJob do
      WatchTheChaseJob.perform_now
    end

    assert_not_predicate WantedRecord.sole, :on_the_way?
  end

  test "a record still coming is still coming" do
    want("Nirvana", "In Utero", plays: 793)
    WantedRecord.sole.sought(hash: "abc", name: "In Utero")
    @qbit.going("abc", 42)

    WatchTheChaseJob.perform_now

    assert_predicate WantedRecord.sole, :on_the_way?
    assert_equal 42, OnTheWay.new(@gaston).all.sole.progress
  end

  private

  def want(artist, title, plays:)
    WantedRecord.create!(artist:, title:, plays:)
  end

  def edition(name, seeders:)
    { hash: name, name:, magnet: "magnet:#{name}", seeders:, bytes: 400_000_000, listed_by: 1 }
  end
end
