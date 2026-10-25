# frozen_string_literal: true
module Authify
  module GeneratorViews
    def plain_view!(relative)
      return unless options[:views] == "plain"
      path = File.join(destination_root, relative)
      return unless File.file?(path)
      File.write(path, Authify::GeneratorViews.plain(File.read(path)))
    end
    def self.plain(content)
      content.gsub(/,?\s*class: "[^"]*"/, "").gsub(/ class="[^"]*"/, "")
    end
  end
end
