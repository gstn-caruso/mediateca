# A file on disk that we are willing to serve.
#
# Paths reach us from the catalog, which a scanner filled from whatever was on
# disk. The media root is the trust boundary: anything resolving outside it —
# via `..`, an absolute path, a lookalike sibling directory, or a symlink —
# is refused before it can be read.
class MediaFile
  Forbidden = Class.new(StandardError)

  attr_reader :path

  def initialize(path, root: self.class.root)
    @root = ::File.realpath(root.to_s)
    @path = within_root(path.to_s)
  end

  def self.root
    Rails.configuration.x.media_root
  end

  def exist?
    ::File.file?(path)
  end

  private

  def within_root(candidate)
    resolved = resolve_symlinks(::File.expand_path(candidate))

    raise Forbidden, "#{candidate.inspect} falls outside #{@root.inspect}" unless resolved.start_with?("#{@root}/")

    resolved
  end

  # A missing file cannot be resolved through symlinks, but the directories
  # above it can — and they are what decide whether it would land inside the
  # root. So walk up to the deepest ancestor that exists, resolve that, and
  # re-attach the rest.
  def resolve_symlinks(absolute)
    missing = []
    existing = absolute

    until ::File.exist?(existing)
      parent = ::File.dirname(existing)
      break if parent == existing

      missing.unshift(::File.basename(existing))
      existing = parent
    end

    ::File.join(::File.realpath(existing), *missing)
  end
end
