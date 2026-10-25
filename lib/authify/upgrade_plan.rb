# frozen_string_literal: true
require "digest"
require "fileutils"
require "open3"
require "tmpdir"

module Authify
  class UpgradePlan
    Entry = Struct.new(:path, :status, :content, :original, keyword_init: true)
    attr_reader :entries

    def initialize(root:, candidates:, baselines: {})
      @root = File.realpath(root)
      @entries = candidates.map do |path, desired|
        validate_path!(path)
        full = File.join(@root, path)
        current = File.file?(full) ? File.read(full) : nil
        baseline = baselines[path]
        status, content = if current == desired
                            [:unchanged, desired]
                          elsif current.nil?
                            [:create, desired]
                          elsif baseline && baseline == desired
                            [:unchanged, current]
                          elsif baseline && current == baseline
                            [:update, desired]
                          elsif baseline
                            merge(current, baseline, desired)
                          else
                            [:conflict, desired]
                          end
        Entry.new(path: path, status: status, content: content, original: current)
      end
    end

    def conflicts? = entries.any? { |e| e.status == :conflict }

    def apply!
      raise "Resolve Authify upgrade conflicts before applying." if conflicts?
      entries.each do |e|
        validate_path!(e.path)
        full = File.join(@root, e.path)
        current = File.file?(full) ? File.read(full) : nil
        raise "Application changed during upgrade: #{e.path}; rerun preview." unless current == e.original
      end
      entries.each do |e|
        next if e.status == :unchanged
        validate_path!(e.path)
        path = File.join(@root, e.path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, e.content)
      end
    end

    def write_review!
      entries.reject { |e| e.status == :unchanged }.each do |e|
        path = File.join(".authify/upgrade", e.path + ".proposed")
        validate_path!(path)
        full = File.join(@root, path)
        FileUtils.mkdir_p(File.dirname(full))
        File.write(full, e.content)
      end
    end

    private

    def validate_path!(path)
      raise ArgumentError, "Unsafe upgrade path" if path.start_with?("/") || path.split("/").include?("..")
      cursor = @root
      path.split("/").each do |part|
        cursor = File.join(cursor, part)
        raise ArgumentError, "Refusing symlink: #{path}" if File.symlink?(cursor)
      end
    end

    def merge(current, baseline, desired)
      Dir.mktmpdir("authify-merge") do |dir|
        paths = [current, baseline, desired].each_with_index.map do |content, index|
          File.join(dir, index.to_s).tap { |path| File.write(path, content) }
        end
        output, _error, status = Open3.capture3("git", "merge-file", "-p", "-L", "application", "-L", "previous Authify", "-L", "new Authify", *paths)
        status.success? ? [:merge, output] : [:conflict, output.empty? ? desired : output]
      end
    rescue Errno::ENOENT
      [:conflict, desired]
    end
  end
end
