module ApplicationCable
  # Nobody is identified here, on purpose. The only thing that travels down this
  # socket is a deploy saying it went live — an instruction to refresh, carrying
  # no library, no profile and no music. There is nothing to tell one listener
  # from another for, and nothing to leak by not doing it.
  class Connection < ActionCable::Connection::Base
  end
end
