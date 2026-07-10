module Music
  # How a file is encoded, as opposed to what it was tagged: the codec, and the
  # numbers that measure its fidelity. Lossless files are told apart by depth
  # and sample rate ("16 / 44.1"); lossy ones by their bitrate ("320").
  #
  # `sample_rate` and `bit_rate` are in hertz and bits per second; `bit_depth`
  # is bits, and is nil for a codec that has no fixed one.
  Audio = Data.define(:codec, :bit_depth, :sample_rate, :bit_rate)
end
