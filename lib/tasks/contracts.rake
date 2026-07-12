# The tests that need somebody else's server to be up.
#
# `bin/rails test` runs every test under test/, minus the ones Rails already
# knows better than to run — system tests. test/contracts/network belongs on that
# list: the tests in it ask MusicBrainz, Wikidata and Commons whether they still
# answer the way we recorded them, and that is a question about the world, not
# about the change being deployed. A bad minute at MusicBrainz is not a reason a
# comment cannot be moved.
#
# So they run at night, on their own — .github/workflows/contracts.yml — where a
# red build is news rather than a locked door.
ENV["DEFAULT_TEST_EXCLUDE"] ||= "test/{system,dummy,fixtures,contracts/network}/**/*_test.rb"

namespace :test do
  desc "Ask the world whether it still answers the way we recorded it"
  task contracts: %w[test:prepare] do
    # One process, so one client, so one call a second. MusicBrainz asks to be
    # called once a second and answers 503 when it isn't — and a throttle that
    # lives inside a client cannot hold across four of them, in four forked
    # processes, that have never heard of each other.
    ENV["PARALLEL_WORKERS"] = "1"

    # Named out loud, so the exclusion above does not apply: it is only the tests
    # nobody asked for by name that get skipped over.
    Rails::TestUnit::Runner.run_from_rake("test", [ "test/contracts" ])
  end
end
