# frozen_string_literal: true
require "tempfile"
require "fileutils"

module Authify
  module AtomicFile
    def self.validate!(root, relative)
      parts = relative.to_s.split("/")
      raise ArgumentError, "Unsafe Authify path" if relative.to_s.start_with?("/") || parts.empty? || parts.any? { |part| ["", ".", ".."].include?(part) }
      cursor = root
      parts.each_with_index do |part, index|
        cursor = File.join(cursor, part)
        raise ArgumentError, "Refusing symlink: #{relative}" if File.symlink?(cursor)
        if File.exist?(cursor)
          expected = index == parts.length - 1 ? File.file?(cursor) : File.directory?(cursor)
          raise ArgumentError, "Unexpected file type: #{relative}" unless expected
        end
      end
    end

    def self.write(path, content, mode: nil)
      FileUtils.mkdir_p(File.dirname(path))
      permissions = mode || (File.exist?(path) ? File.stat(path).mode & 0o777 : 0o644)
      Tempfile.create([".authify-", ".tmp"], File.dirname(path)) do |file|
        file.chmod(permissions)
        file.write(content)
        file.flush
        file.fsync
        File.rename(file.path, path)
      end
    end
  end
end
