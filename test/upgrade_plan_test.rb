require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../lib/authify/upgrade_plan"

class UpgradePlanTest < Minitest::Test
  def with_app
    Dir.mktmpdir do |root|
      FileUtils.mkdir_p(File.join(root, "app"))
      yield root
    end
  end

  def test_preview_does_not_write_and_pristine_update_applies
    with_app do |root|
      path = "app/session.rb"
      File.write(File.join(root, path), "old\n")
      plan = Authify::UpgradePlan.new(root: root, candidates: { path => "new\n" }, baselines: { path => "old\n" })
      assert_equal :update, plan.entries.first.status
      assert_equal "old\n", File.read(File.join(root, path))
      plan.apply!
      assert_equal "new\n", File.read(File.join(root, path))
    end
  end

  def test_merges_nonoverlapping_customization
    with_app do |root|
      baseline = "class Session\n  TIMEOUT = 30\n\n  # hooks\nend\n"
      customized = baseline.sub("# hooks", "def custom_hook = true")
      desired = baseline.sub("30", "15")
      File.write(File.join(root, "app/session.rb"), customized)
      plan = Authify::UpgradePlan.new(root: root, candidates: { "app/session.rb" => desired }, baselines: { "app/session.rb" => baseline })
      refute plan.conflicts?
      plan.apply!
      result = File.read(File.join(root, "app/session.rb"))
      assert_includes result, "TIMEOUT = 15"
      assert_includes result, "def custom_hook = true"
    end
  end

  def test_conflict_blocks_every_application_write
    with_app do |root|
      File.write(File.join(root, "app/session.rb"), "custom\n")
      plan = Authify::UpgradePlan.new(root: root, candidates: { "app/new.rb" => "new\n", "app/session.rb" => "replacement\n" })
      assert plan.conflicts?
      assert_raises(RuntimeError) { plan.apply! }
      refute File.exist?(File.join(root, "app/new.rb"))
      assert_equal "custom\n", File.read(File.join(root, "app/session.rb"))
      plan.write_review!
      assert File.exist?(File.join(root, ".authify/upgrade/app/session.rb.proposed"))
    end
  end

  def test_rejects_symlinks_and_parent_paths
    with_app do |root|
      File.symlink("/tmp", File.join(root, "app/link"))
      ["../escape", "app/link/escape"].each do |path|
        assert_raises(ArgumentError) { Authify::UpgradePlan.new(root: root, candidates: { path => "x" }) }
      end
    end
  end
end
