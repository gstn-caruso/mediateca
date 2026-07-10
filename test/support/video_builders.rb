# Builds the description of a media file the way Video::Probe reports it, so the
# playback rules can be tested without ever opening a video.
module VideoBuilders
  def media(container: "mkv", video: "h264", audios: [ "aac" ], channels: 2)
    Video::Media.new(
      container:,
      video: video && Video::Stream.new(index: 0, codec: video, channels: nil, language: nil, title: nil),
      audios: audios.each_with_index.map do |codec, position|
        Video::Stream.new(index: position + 1, codec:, channels:, language: nil, title: nil)
      end
    )
  end
end
