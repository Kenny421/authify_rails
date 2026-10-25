# frozen_string_literal: true
require "digest"
require "fileutils"
require "open3"
require "tmpdir"
require_relative "atomic_file"

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
      applied = []
      begin
        entries.each do |e|
          next if e.status == :unchanged
          validate_path!(e.path)
          path = File.join(@root, e.path)
          mode = File.exist?(path) ? File.stat(path).mode & 0o777 : nil
          AtomicFile.write(path, e.content)
          applied << [e, mode]
        end
      rescue StandardError => error
        rollback_errors = []
        applied.reverse_each do |entry, mode|
          path = File.join(@root, entry.path)
          begin
            entry.original.nil? ? File.delete(path) : AtomicFile.write(path, entry.original, mode: mode)
          rescue StandardError => rollback_error
            rollback_errors << "#{entry.path}: #{rollback_error.class}"
          end
        end
        raise "Authify upgrade failed (#{error.class}: #{error.message}); restore these files from git: #{rollback_errors.join(', ')}" unless rollback_errors.empty?
        raise
      end
    end

    def write_review!
      entries.reject { |e| e.status == :unchanged }.each do |e|
        path = File.join(".authify/upgrade", e.path + ".proposed")
        validate_path!(path)
        full = File.join(@root, path)
        FileUtils.mkdir_p(File.dirname(full))
        AtomicFile.write(full, e.content)
      end
    end

    private

    def validate_path!(path)
      AtomicFile.validate!(@root, path)
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
