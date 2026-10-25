# frozen_string_literal: true
module Authify
  class MissingTenant < StandardError; end

  def self.resolve_tenant(request)
    return unless configuration.tenant_enabled
    resolver = configuration.tenant_resolver
    raise MissingTenant, "Configure Authify.tenant_resolver using trusted request context" unless resolver
    id = resolver.call(request)
    raise MissingTenant, "Tenant context is required" if id.blank?
    id
  end

  def self.user_in_current_tenant?(user)
    !configuration.tenant_enabled || user_scope.where(id: user.id).exists?
  end

  def self.user_scope
    scope = configuration.user_class.all
    return scope unless configuration.tenant_enabled
    id = Current.authify_tenant_id
    raise MissingTenant, "Tenant context is required" if id.blank?
    scope.where(configuration.tenant_key => id)
  end
end
