require "test_helper"
require "tmpdir"

class MediaFileTest < ActiveSupport::TestCase
  test "un archivo dentro de la raíz se puede servir" do
    within_root do |root|
      flac = create(root, "Almafuerte/01 - Desencuentro.flac")

      assert MediaFile.new(flac, root:).exist?
    end
  end

  test "un archivo dentro de la raíz que ya no está en disco no se puede servir" do
    within_root do |root|
      refute MediaFile.new("#{root}/borrado.flac", root:).exist?
    end
  end

  # Los paths salen de la base, no de la request; pero la base la llena un
  # scanner que lee lo que haya en disco. La raíz es el límite de confianza.
  test "un path que se escapa de la raíz con .. es rechazado" do
    within_root do |root|
      assert_raises(MediaFile::Forbidden) { MediaFile.new("#{root}/../../etc/passwd", root:) }
    end
  end

  test "un path absoluto fuera de la raíz es rechazado" do
    within_root do |root|
      assert_raises(MediaFile::Forbidden) { MediaFile.new("/etc/passwd", root:) }
    end
  end

  # Un prefijo compartido no es estar adentro: /mnt/data-secreto no está
  # dentro de /mnt/data.
  test "un hermano con el mismo prefijo que la raíz es rechazado" do
    within_root do |root|
      assert_raises(MediaFile::Forbidden) { MediaFile.new("#{root}-secreto/robado.flac", root:) }
    end
  end

  test "un symlink que apunta fuera de la raíz es rechazado" do
    within_root do |root|
      secret = File.join(Dir.mktmpdir, "secreto.txt")
      File.write(secret, "afuera")
      link = File.join(root, "inocente.flac")
      File.symlink(secret, link)

      assert_raises(MediaFile::Forbidden) { MediaFile.new(link, root:) }
    end
  end

  private

  def within_root
    Dir.mktmpdir("media-root") { |root| yield root }
  end

  def create(root, relative)
    File.join(root, relative).tap do |path|
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "fake flac bytes")
    end
  end
end
