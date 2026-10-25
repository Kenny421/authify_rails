# frozen_string_literal: true

module Authify
  class Engine < ::Rails::Engine
    initializer "authify.filter_parameters" do |app|
      app.config.filter_parameters += %i[
        password password_confirmation current_password token
        access_token refresh_token otp_code recovery_code
      ]
    end
  end
end
