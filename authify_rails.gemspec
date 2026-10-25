# frozen_string_literal: true

require_relative "lib/authify/version"

Gem::Specification.new do |spec|
  spec.name = "authify_rails"
  spec.version = Authify::VERSION
  spec.authors = ["Kenroy Reid"]
  spec.email = []
  spec.summary = "One-command, Rails-native authentication installer"
  spec.description = "Generates secure, editable Rails authentication with optional Google/Facebook OAuth, roles, TOTP, API tokens, sudo mode, admin tools, and multi-tenancy."
  spec.homepage = "https://github.com/Kenny421/authify_rails"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(__dir__) do
    Dir["{app,config,lib}/**/*", "LICENSE.txt", "README.md", "CHANGELOG.md", "SECURITY.md", "UPGRADING.md", "CONTRIBUTING.md"]
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 8.0", "< 9.0"
  spec.add_dependency "bcrypt", "~> 3.1"
end
