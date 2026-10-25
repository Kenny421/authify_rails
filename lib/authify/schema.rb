# frozen_string_literal: true

module Authify
  # Used by generated migrations. Existing data and column definitions are preserved.
  module Schema
    USER_COLUMNS = {
      email: :string, password_digest: :string, email_verified_at: :datetime,
      email_verification_token_digest: :string, email_verification_sent_at: :datetime,
      pending_email: :string, email_change_token_digest: :string, email_change_sent_at: :datetime,
      password_reset_token_digest: :string, password_reset_sent_at: :datetime,
      failed_login_attempts: :integer, locked_until: :datetime, disabled_at: :datetime,
      last_signed_in_at: :datetime, password_changed_at: :datetime,
      created_at: :datetime, updated_at: :datetime
    }.freeze

    def self.ensure_user!(migration, table)
      existing = migration.connection.columns(table).index_by(&:name)
      USER_COLUMNS.each do |name, type|
        column = existing[name.to_s]
        next unless column
        compatible = column.type == type || (type == :string && column.type == :text)
        raise ActiveRecord::MigrationError, "Authify: incompatible #{table}.#{name} (#{column.type}); expected #{type}. Review manually." unless compatible
      end
      USER_COLUMNS.each do |name, type|
        next if existing.key?(name.to_s)
        opts = name == :failed_login_attempts ? { default: 0, null: false } : {}
        migration.add_column(table, name, type, **opts)
      end
      { email: "LOWER(email)", pending_email: "LOWER(pending_email)" }.each do |name, expression|
        # Do not reintroduce global constraints after an explicit tenant conversion.
        next if migration.index_name_exists?(table, "index_#{table}_on_tenant_lower_#{name}")
        index_name = "index_#{table}_on_lower_#{name}"
        migration.add_index(table, expression, unique: true, name: index_name) unless migration.index_name_exists?(table, index_name)
      end
      %i[password_reset_token_digest email_verification_token_digest email_change_token_digest].each do |column|
        migration.add_index(table, column, unique: true) unless migration.index_exists?(table, column, unique: true)
      end
    end
  end
end
