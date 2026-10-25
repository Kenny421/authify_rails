# frozen_string_literal: true

module Authify
  # Used by generated migrations. Existing data and column definitions are preserved.
  module Schema
    USER_COLUMNS = {
      email: :string, password_digest: :string, authify_security_version: :integer, email_verified_at: :datetime,
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
        opts = %i[failed_login_attempts authify_security_version].include?(name) ? { default: 0, null: false } : {}
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

module Authify
  module Schema
    def self.ensure_abuse!(migration)
      return if migration.table_exists?(:authify_abuse_buckets)
      migration.create_table :authify_abuse_buckets do |t|
        t.string :kind, null: false
        t.string :action, null: false
        t.string :source_digest, null: false
        t.string :account_digest, null: false
        t.datetime :window_started_at, null: false
        t.bigint :count, null: false, default: 0
        t.datetime :expires_at, null: false
        t.timestamps
      end
      migration.add_index :authify_abuse_buckets, %i[kind action source_digest account_digest window_started_at], unique: true, name: :index_authify_abuse_identity
      migration.add_index :authify_abuse_buckets, %i[action source_digest window_started_at], name: :index_authify_abuse_source
      migration.add_index :authify_abuse_buckets, %i[action account_digest window_started_at], name: :index_authify_abuse_account
      migration.add_index :authify_abuse_buckets, :expires_at
    end
  end
end

module Authify
  module Schema
    def self.ensure_security!(migration, user_table)
      { user_table => { authify_security_version: [:integer, { default: 0, null: false }] },
        authify_sessions: { authify_security_version: [:integer, { default: 0, null: false }], reauthenticated_at: [:datetime, {}], reauthentication_method: [:string, {}] },
        authify_api_tokens: { authify_security_version: [:integer, { default: 0, null: false }] }
      }.each do |table, columns|
        next unless migration.table_exists?(table)
        columns.each do |name, (type, options)|
          existing = migration.connection.columns(table).find { |column| column.name == name.to_s }
          if existing
            raise ActiveRecord::MigrationError, "Authify: incompatible #{table}.#{name}; expected #{type}. Review manually." unless existing.type == type
          else
            migration.add_column(table, name, type, **options)
          end
        end
      end
      return if migration.table_exists?(:authify_sign_in_challenges)
      migration.create_table :authify_sign_in_challenges do |t|
        t.references :user, null: false, foreign_key: { to_table: user_table }
        t.string :token_digest, null: false
        t.integer :authify_security_version, null: false
        t.bigint :credential_id, null: false
        t.integer :attempts, null: false, default: 0
        t.datetime :expires_at, null: false
        t.datetime :consumed_at
        t.timestamps
      end
      migration.add_index :authify_sign_in_challenges, :token_digest, unique: true
      migration.add_index :authify_sign_in_challenges, :expires_at
    end
  end
end
