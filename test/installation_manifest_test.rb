require "minitest/autorun"
require "tmpdir"
require_relative "../lib/authify/installation_manifest"

class InstallationManifestTest < Minitest::Test
  def test_corrupt_or_wrongly_shaped_manifests_fail_closed
    ["features: [", "[]", "features: []", "files: {app.rb: 3}", "features: {core: enabled}", ""].each do |content|
      Dir.mktmpdir do |root|
        FileUtils.mkdir_p(File.join(root, "config"))
        path = File.join(root, "config/authify.yml")
        File.write(path, content)
        assert_raises(Authify::InstallationManifest::InvalidManifest) { Authify::InstallationManifest.new(root: root) }
        assert_equal content, File.read(path)
      end
    end
  end

  def test_manifest_cannot_read_or_write_through_symlinks
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "config"))
      target = File.join(root, "outside.yml")
      File.write(target, "features: {}")
      File.symlink(target, File.join(root, "config/authify.yml"))
      assert_raises(ArgumentError) { Authify::InstallationManifest.new(root: root) }
      assert_equal "features: {}", File.read(target)
    end
  end
end
