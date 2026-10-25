# Authify Rails

Authify Rails generates editable authentication code for Rails 8: registration,
password sign-in, email verification, password recovery, sessions, security emails,
and optional MFA, passkeys, OAuth, API tokens, roles, and tenant isolation.

**Status:** 0.4.0 is under review. Test generated changes in your application before
production use. Updating the gem does not update code already generated in an app.

## Setup guide

- [Upgrade an existing app](#upgrade-an-existing-app)
- [Install in a new app or add features](#install-in-a-new-app-or-add-features)
- [Know where settings belong](#know-where-settings-belong)
- [Configure email and application security](#configure-email-and-application-security)
- [Set up MFA and sudo](#set-up-mfa-and-sudo)
- [Set up bot protection with Turnstile](#set-up-bot-protection-with-turnstile)
- [Set up passkeys](#set-up-passkeys)
- [Set up API tokens](#set-up-api-tokens)
- [Set up OAuth](#set-up-oauth)
- [Set up roles and tenants](#set-up-roles-and-tenants)
- [Configure Kamal deployments](#configure-kamal-deployments)
- [Test, monitor, and clean up](#test-monitor-and-clean-up)
- [Troubleshooting](#troubleshooting)

## Requirements

- Rails 8.0 or newer, below Rails 9.
- Ruby 3.2 or newer for compatibility; use a maintained release such as Ruby 3.4
  for deployment. Ruby 3.2 compatibility testing does not make that end-of-life
  runtime suitable for production.
- Active Record and browser cookies/sessions.
- SQLite or PostgreSQL for the generated database abuse counters; both are tested.
- Git for three-way merging of customized generated files during upgrades.

Authify does not install a mail provider, configure your deployment secrets,
replace authorization policies, or automatically migrate Devise/other auth systems.

## Upgrade an existing app

Run these commands **inside your Rails application's folder**, not the gem's folder.
Commit your current app changes and back up any important database before starting.
Use a development/staging database and separate test database for this walkthrough.

### 1. Select the reviewed code

```bash
git status --short
git switch -c test/authify-upgrade
```

Resolve or commit outstanding changes first. Replace the existing Authify entry
in the app's `Gemfile` with this exact reviewed revision; do not add a second entry:

```ruby
gem "authify_rails",
    git: "https://github.com/Kenny421/authify_rails.git",
    ref: "bc230e093ddb8fc52ddadada612a65833af175a0"
```

This pins the tested code from [PR #1](https://github.com/Kenny421/authify_rails/pull/1).
It does not assume that the unreleased changes are available from RubyGems or `main`.
When intentionally testing later branch work, replace `ref:` with
`branch: "feat/safe-authify-upgrades"`; a branch follows changing code.

```bash
bundle update authify_rails
```

### 2. Preview and apply generated changes

```bash
bin/rails generate authify:upgrade --dry-run
bin/rails generate authify:upgrade
git diff
```

The preview writes nothing. Conflicts stop application-file updates and leave
proposals under `.authify/upgrade/`, preserving directories. Review and resolve
conflicts, then rerun the generator. Never apply a file with merge markers.

The upgrade preserves your routes, User model, ApplicationController, layout,
Gemfile, branding initializer, and OAuth credentials initializer. Review custom
views and integrations against the proposals. Keep `config/authify.yml`: it holds
installation metadata and template baselines. Do not rerun the installer to repair
missing metadata or manually change the recorded version to bypass an upgrade.

### 3. Migrate and validate

After reviewing the diff, run:

```bash
bin/rails db:migrate
RAILS_ENV=test bin/rails db:prepare
bin/rails authify:doctor
bin/rails test
```

Check that any `DATABASE_URL` points to the intended database before database
commands. Follow the configuration sections below if doctor reports missing keys,
mailer settings, or provider configuration. Then start the app:

```bash
bin/dev
# If the app has no bin/dev, use: bin/rails server
```

Even if earlier 0.4.0 migrations ran, apply the generated
`HardenAuthifyCredentials` migration. It adds credential-version/proof fields and
single-use MFA challenges. Keep old workers from serving the new code against an
unmigrated database; coordinate migrations and replacement of all workers.

Important behavior changes to test:

- Password/email/factor changes and tenant transfers invalidate earlier browser
  sessions, API tokens, and pending sign-ins. Recreate affected API tokens.
- Sensitive enrollment and token creation require explicit identity confirmation;
  a newly created login session alone is insufficient.
- OAuth no longer links an existing account automatically by matching email.
- Recovery codes are shown once in the response, not stored in the session cookie.
- Intrinsic MFA and identity-confirmation budgets apply even in observation mode.

See [UPGRADING.md](UPGRADING.md) for baseline compatibility, migration details,
interrupted upgrades, and rollback planning. Older/unrecognized custom installations
need manual review rather than guessed baselines.

## Install in a new app or add features

To test this revision in a new app, use the same pinned Git entry above, then:

```bash
bundle install
bin/rails generate authify:install --two-factor --sudo
bin/rails db:migrate
```

Configure email and encryption below before running doctor. For core authentication
only, omit the feature flags. For every optional feature, use `--all` and configure
each provider before deployment; tenant enforcement remains explicitly opt-in.

| Flag | What it adds | Required setup |
| --- | --- | --- |
| `--two-factor` | TOTP enrollment and recovery codes | Active Record encryption keys |
| `--sudo` | Explicit identity confirmation | Sensitive-action controller rules |
| `--passkeys` | WebAuthn enrollment, sign-in, management | Trusted origins, RP ID, real-device testing |
| `--api` | Digested Bearer tokens and scopes | Scope allowlist and resource authorization |
| `--oauth` | OmniAuth strategies and callbacks | Provider credentials and verified-email policy |
| `--roles` | Role assignments | Application-owned authorization rules |
| `--admin` | Authentication-event viewer | Roles installed and trusted admin assignment |
| `--multi-tenant` | Tenant column and resolver initializer | Trusted tenant resolution, backfill, reviewed indexes |
| `--all` | All optional features | All applicable setup above |

Add missing features later with the same installer; it skips installed features:

```bash
bin/rails generate authify:install --passkeys --api
bin/rails db:migrate
```

Upgrade existing generated code first if the installer requests it. Installed user
model and view mode are retained. `--admin` requires `--roles` unless roles already
exist. The generator adds dependencies and runs Bundler unless `--skip-bundle` is set.

For a first installation, custom options include:

```bash
bin/rails generate authify:install --user-model=Account --views=plain
```

Views can be `tailwind`, `plain`, or `none`. Tailwind mode assumes the host app
already builds Tailwind CSS; choose `plain` otherwise. With `none`, build your own forms,
including CSRF protection, challenge fields, and explicit confirmation inputs.
Existing home files and root routes are preserved. Existing authentication
integrations detected by preflight require an explicit migration plan.

### Find the generated pages

```bash
bin/rails routes -g authify
```

| Page | Path |
| --- | --- |
| Sign in / register | `/sign-in` / `/sign-up` |
| Request password reset | `/forgot-password` |
| Request verification email | `/verify-email` |
| Change password / email | `/account/password` / `/account/email` |
| Session history and revocation | `/account/sessions` |

Optional feature paths are listed in their setup sections below.

## Know where settings belong

All paths in this guide refer to the **host Rails app**.

| File or setting | Purpose |
| --- | --- |
| `config/initializers/authify.rb` | Branding, password/session policy, API scopes |
| `config/initializers/authify_abuse.rb` | Observe/enforce mode and challenge adapter |
| `config/initializers/authify_passkeys.rb` | WebAuthn trusted origins and RP ID |
| `config/initializers/authify_oauth.rb` | OmniAuth providers and credentials |
| `config/initializers/authify_tenant.rb` | Trusted tenant resolver and activation |
| `config/credentials.yml.enc` or environment-specific credentials | Encrypted secrets and MFA encryption keys |
| Deployment environment variables | Settings read by generated initializers |
| `config/authify.yml` | Installation metadata; not a place for secrets |

Restart Rails after changing initializers or environment variables. Exported shell
variables apply only to processes launched from that shell. A `.env` file is not
loaded automatically by Rails; use your existing loader or deployment secret store.

The Turnstile, passkey, OAuth, and tenant initializers read environment variables
by default. Adding values to Rails credentials alone does not connect them to
these initializers. The optional credentials-based Turnstile example below shows
how to wire credentials directly.

## Configure email and application security

### Mail delivery and HTTPS

Set link generation in the appropriate environment file:

```ruby
# config/environments/development.rb
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
```

```ruby
# config/environments/production.rb
config.force_ssl = true
config.action_mailer.default_url_options = {
  host: "app.example.com", protocol: "https"
}
```

Configure your application's SMTP/provider adapter. For an SMTP provider, an
example production configuration is:

```ruby
config.action_mailer.delivery_method = :smtp
config.action_mailer.smtp_settings = {
  address: ENV.fetch("SMTP_ADDRESS"),
  port: ENV.fetch("SMTP_PORT", "587").to_i,
  user_name: ENV.fetch("SMTP_USERNAME"),
  password: ENV.fetch("SMTP_PASSWORD"),
  authentication: :plain,
  enable_starttls: true
}
```

Supply those variables through your secret manager and adapt TLS/authentication
to your provider's instructions. Verify the sender/domain with that provider.
Authify uses `deliver_later`: run the application's Active Job workers and confirm
that verification and reset emails are actually delivered. Solid Queue users need
a worker consuming the queue configured for Action Mailer.

### Branding and security policy

Edit the existing block in `config/initializers/authify.rb`:

```ruby
Authify.configure do |config|
  config.app_name = "My App"
  config.company_name = "My Company"
  config.mailer_from = "security@app.example.com"
  config.support_email = "support@app.example.com"
  config.logo_url = "https://app.example.com/logo-email.png"
  config.primary_color = "#2563eb"

  config.password_minimum_length = 12
  config.password_maximum_length = 128
  config.pwned_password_check = true
  config.pwned_fail_closed = false
  config.pwned_timeout = 3.seconds
  config.email_verification_required = true

  config.session_idle_timeout = 30.minutes
  config.session_absolute_timeout = 30.days
  config.remember_me_duration = 30.days
  config.sudo_timeout = 10.minutes

  config.email_notifications_enabled = true
  config.new_sign_in_notifications = true
  config.password_change_notifications = true
end
```

Preserve the generated `user_class_name` setting, especially for custom user models.
The Pwned Passwords checker sends a five-character hash prefix, never the plaintext
password. Invalid passwords are checked locally first. The default permits valid
passwords during provider outages; set `pwned_fail_closed = true` if rejecting such
changes during outages is your chosen policy. Rails/bcrypt also enforces its
72-byte password limit; a larger character setting does not remove that limit.

Remembered sessions bypass idle expiration but retain absolute expiration and
revocation. Cookies are encrypted, HTTP-only, SameSite Lax, and Secure in the Rails
production environment. Configure a shared production cache store, such as your
existing Solid Cache setup, for Rails controller rate limits. Database risk
counters do not replace that cache or correct trusted-proxy configuration.

Generated HTML/plain-text mail previews are at `/rails/mailers/authify_mailer`
in development. New-sign-in alerts are sent when both the IP and user-agent are
new for that account; a recognized IP or user-agent suppresses that alert.

### Protect application controllers

```ruby
class DashboardController < ApplicationController
  require_authentication
end
```

Use `current_user` and `authenticated?` in views/controllers. Add Pundit, Action
Policy, or your own authorization rules for resource access; authentication alone
is not authorization.

## Set up MFA and sudo

### Configure encryption once

If two-factor support is installed and the app does not already have Active Record
encryption keys, generate them:

```bash
bin/rails db:encryption:init
EDITOR="nano" bin/rails credentials:edit
```

Copy the generated values into the credentials file:

```yaml
active_record_encryption:
  primary_key: YOUR_GENERATED_PRIMARY_KEY
  deterministic_key: YOUR_GENERATED_DETERMINISTIC_KEY
  key_derivation_salt: YOUR_GENERATED_SALT
```

For separate production credentials, edit the corresponding file instead:

```bash
EDITOR="nano" bin/rails credentials:edit --environment production
```

Rails reads this encryption namespace automatically. Supply the matching credential
key to each worker, typically through `RAILS_MASTER_KEY`. Keep existing encryption
keys when upgrading: replacing them can make stored MFA secrets unreadable. Never
commit plaintext credential keys. See the [Rails encryption setup guide](https://guides.rubyonrails.org/v8.0/active_record_encryption.html#setup).

### Enroll and test an authenticator

```bash
bin/rails authify:doctor
bin/rails routes -g two_factor
```

Sign in with a verified test account, open `/two_factor/new`, scan the QR code with
an authenticator app, and submit the current password plus the generated code.
Save the recovery codes immediately; they are displayed once. Sign out and sign
in again: `/two-factor` is the separate login challenge for an enrolled account.

TOTP and recovery codes are single-use. A code just used for sign-in may need to
advance to the next authenticator timestep before another sensitive action.
Disabling MFA and replacing recovery codes require password plus an enrolled
code. Factor changes invalidate other sessions, pending sign-ins, and API tokens.

### Require explicit identity confirmation

With `--sudo` installed:

```ruby
class AccountDeletionController < ApplicationController
  require_authentication
  require_sudo only: :destroy

  def destroy
    # Apply the application's authorization and deletion policy here.
  end
end
```

Use `require_sudo freshness: 2.minutes, only: :destroy` for a tighter window.
The confirmation page is `/sudo/new`. Users with MFA must provide an existing
factor as well as their password. Successful explicit confirmation rotates the
session. Recent login alone does not grant enrollment/token-management permissions.

Custom JSON clients must replace their CSRF token from the `X-CSRF-Token` response
header after session rotation. The generated passkey browser script does this.

## Set up bot protection with Turnstile

No webhook is required. You need a Turnstile **site key** for the browser and a
**secret key** for server-side validation, not a Cloudflare account API token.

### 1. Create a widget

Open Cloudflare's Turnstile dashboard, add a widget, select Managed mode, and add
the hostnames where this app runs. Keep staging and production widget settings
separate. Copy the site key and secret key. See [Cloudflare's widget setup](https://developers.cloudflare.com/turnstile/get-started/widget-management/dashboard/).

### 2. Supply settings to Rails

The generated `config/initializers/authify_abuse.rb` reads:

| Variable | Example | Meaning |
| --- | --- | --- |
| `AUTHIFY_ABUSE_MODE` | `observe` | `off`, `observe`, or `enforce` |
| `AUTHIFY_TURNSTILE_SITE_KEY` | Your widget site key | Public browser key |
| `AUTHIFY_TURNSTILE_SECRET_KEY` | Your widget secret key | Private backend key |
| `AUTHIFY_TURNSTILE_HOSTNAMES` | `app.example.com,staging.example.com` | Exact allowed request hosts |

Use hostname values without schemes, ports, paths, or wildcards. Authify's
allowlist is exact: list each used subdomain even if the widget allows a parent
domain. For local manual testing, configure a separate widget allowing `localhost`
and use `AUTHIFY_TURNSTILE_HOSTNAMES=localhost`.

For a local shell, export your values and then launch Rails from that same shell.
Use your secret loader for the private key rather than committing it to files:

```bash
export AUTHIFY_ABUSE_MODE=observe
export AUTHIFY_TURNSTILE_SITE_KEY='YOUR_PUBLIC_SITE_KEY'
export AUTHIFY_TURNSTILE_HOSTNAMES='localhost'
# Supply AUTHIFY_TURNSTILE_SECRET_KEY through your local secret loader.
bin/dev
```

Restart the app after changing these values. Cloudflare's public dummy keys are
for component tests, not production protection. For end-to-end Authify testing,
use a real staging widget: the verifier also checks the returned hostname/action.
See [Cloudflare's testing guide](https://developers.cloudflare.com/turnstile/troubleshooting/testing/).

### Optional: read Turnstile secrets from Rails credentials

If you prefer credentials to environment variables, add this to the credentials
file used by that environment:

```yaml
turnstile:
  site_key: YOUR_PUBLIC_SITE_KEY
  secret_key: YOUR_PRIVATE_SECRET_KEY
  hostnames:
    - app.example.com
```

Replace the provider setup in `config/initializers/authify_abuse.rb` with:

```ruby
Authify.configure do |config|
  config.abuse_mode = ENV.fetch("AUTHIFY_ABUSE_MODE", "observe").to_sym
  config.turnstile_site_key = Rails.application.credentials.dig(:turnstile, :site_key)
  config.bot_challenge_partial = "authify/turnstile"
  config.bot_challenge_verifier = Authify::TurnstileVerifier.new(
    secret: Rails.application.credentials.dig(:turnstile, :secret_key),
    hostnames: Rails.application.credentials.dig(:turnstile, :hostnames)
  )
end
```

Supply all three credential values; the verifier requires a nonempty secret and
allowed hostnames. Preserve the generated parameter-filter configuration below that block. Choose
one provider configuration source so that later initializers do not override it.

### 3. Check assets, network access, and observation mode

The generator supplies the challenge partial and browser asset. If your app uses
a CSP, append `https://challenges.cloudflare.com` to its script/frame allowlists,
preserving existing origins and nonce settings. Permit the Rails backend to call
Cloudflare's HTTPS Siteverify endpoint. Custom forms must render the configured
partial inside the submitted form and submit `authify_challenge_token`.

In observation mode the app records projected decisions while retaining existing
fixed controls. The widget normally stays hidden because challenges are not
being enforced. This is expected; ordinary users are not challenged on every login.

### 4. Test enforcement in staging, then enable it deliberately

Set the following in the environment of **all web workers**, restart them, and run
doctor using the same settings:

```text
AUTHIFY_ABUSE_MODE=enforce
```

```bash
bin/rails authify:doctor
```

On a dedicated staging account without MFA, make five incorrect password attempts,
then try again to exercise the default challenge threshold. Complete the widget
and use the correct password. Also test expired/duplicate tokens, missing tokens,
provider outages, enrolled MFA, passkeys, and normal users behind a shared network.
Existing account locks from observation mode still apply until they expire.
Doctor checks configuration; it does not perform a real browser/provider test.

With enforcement active, verified challenge success never replaces a correct
password or enrolled MFA. Repeated source/account failures can cause a bounded
cooldown with `Retry-After`. Trusted-browser evidence reduces some soft challenges;
the cookie alone never signs a user in. Attack traffic does not extend automatic
password-failure account locks in enforcement mode. Pre-existing locks remain valid.

Switch back to `AUTHIFY_ABUSE_MODE=observe` and restart if you need to stop adaptive
enforcement while investigating false positives. Intrinsic MFA/confirmation limits
continue to apply. Turnstile is not a replacement for edge-level DDoS protection.

### Thresholds and custom providers

Adjust thresholds in the existing abuse initializer after reviewing traffic:

```ruby
Authify.configure do |config|
  config.abuse_window = 10.minutes
  config.abuse_source_request_limit = 300
  config.abuse_source_failure_threshold = 30
  config.abuse_pair_challenge_threshold = 5
  config.abuse_pair_cooldown_threshold = 10
  config.abuse_account_failure_threshold = 10
  config.abuse_spray_threshold = 10
  config.abuse_public_source_challenge_threshold = 5
  config.abuse_account_request_limit = 5
  config.abuse_device_lifetime = 30.days
end
```

`off` disables adaptive tracking while retaining other authentication controls.
MFA allows five attempts per challenge and ten per account per fixed five-minute
window across IPs/new challenges; issuance allows twenty challenges per account in
that window. Explicit sensitive confirmations allow ten attempts per account per
five minutes. These intrinsic budgets apply in every adaptive mode, fail closed
when storage is unavailable, and do not extend their window on rejection.

All workers need the same counter database and Rails key material. Configure
trusted proxies before relying on `request.remote_ip`. Counters use keyed hashes
of identifiers, including tenant context for accounts, rather than raw email/IP.

A custom provider must configure `bot_challenge_partial` and a callable
`bot_challenge_verifier` accepting `token:`, `request:`, and `action:`. Return exactly
`true` only after backend validation of single use, expected action, and origin.
Never accept a browser-supplied success flag. The built-in adapter verifies
success, hostname, and action using [Cloudflare server validation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/).

## Set up passkeys

```bash
bin/rails generate authify:install --passkeys
bin/rails db:migrate
```

Set these variables in the deployed environment and restart:

```text
AUTHIFY_WEBAUTHN_ORIGINS=https://app.example.com
AUTHIFY_WEBAUTHN_RP_ID=app.example.com
```

Origins include scheme and non-default port, if any; multiple origins are comma
separated. RP ID is a domain without scheme, port, or path. Keep it stable after
enrollment and choose values matching your deployment. Do not use wildcard origins.
Local defaults are `http://localhost:3000` and RP ID `localhost`. Production has no
permissive defaults. Use HTTPS on deployed hosts and a browser supporting
`parseCreationOptionsFromJSON`, `parseRequestOptionsFromJSON`, and credential `toJSON()`.

Open `/passkeys` after sign-in. Confirm with the current password plus an enrolled
MFA code, or use the existing-passkey confirmation button; then add/remove a key.
Test a second device, sign-out/sign-in, cancellation, and recovery. WebAuthn requires
local user verification (device PIN, fingerprint, or face); a verified passkey login
does not also request a TOTP. Server challenges expire after five minutes and are
single-use even for authenticators whose signature counter stays zero.

## Set up API tokens

```bash
bin/rails generate authify:install --api
bin/rails db:migrate
```

Declare permissions in `config/initializers/authify.rb`, then restart:

```ruby
Authify.configure do |config|
  config.api_scopes = %w[books:read books:write]
end
```

The browser-authenticated management endpoints are:

| Request | Behavior |
| --- | --- |
| `GET /api/authify_tokens` | List your token metadata |
| `POST /api/authify_tokens` | Create with `name`, `scopes` array, `current_password`, and `code` if MFA is enabled, or recent explicit confirmation |
| `DELETE /api/authify_tokens/:id` | Revoke your token |

These endpoints require a browser session and CSRF protection, not a Bearer token.
Build an app-owned management UI if needed; the generator provides the controller,
not a complete token-settings page. Creation returns the raw token once. Custom
JSON clients must use the refreshed `X-CSRF-Token` header after confirmation.

For trusted console/operator code, tokens can also be issued explicitly:

```ruby
# bin/rails console; use the configured model instead of User if customized.
user = User.find_by!(email: "test@example.com")
record, raw_token = AuthifyApiToken.issue!(
  user: user, name: "Staging reader", scopes: ["books:read"],
  expires_at: 30.days.from_now
)
```

Store the raw value securely; it cannot be recovered from its digest later. When
tenants are enabled, establish the trusted `Current.authify_tenant_id` first and
use `Authify.user_scope` for lookup; cross-tenant issuance is rejected.

Protect resources separately; this example assumes your app has a `books` association:

```ruby
class Api::BooksController < ActionController::API
  include Authify::ApiAuthentication
  require_api_scope "books:read"

  def index
    render json: Current.user.books
  end
end
```

Send `Authorization: Bearer authify_live_...`. Missing/expired/revoked tokens,
unverified or disabled accounts, wrong tenants, and no-longer-approved scopes are
rejected. Missing required scopes return 403; all declared scopes are required.
An empty scope allowlist permits only unscoped tokens. Add application authorization
for writes and individual resources. Credential/factor/tenant changes invalidate
previously issued tokens.

## Set up OAuth

```bash
bin/rails generate authify:install --oauth
bin/rails db:migrate
```

The initializer reads `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `FACEBOOK_APP_ID`,
and `FACEBOOK_APP_SECRET`. Create provider applications, configure the appropriate
credentials, and register matching callback URLs:

```text
https://app.example.com/auth/google_oauth2/callback
https://app.example.com/auth/facebook/callback
```

Provider authorization starts with POST and Rails CSRF protection. Existing
identities are matched by provider and UID. **An existing local account is never
automatically linked by email.** New identities require a boolean
`extra.raw_info.email_verified: true`; generic `verified` flags and string values
are not sufficient.

The Facebook strategy is installed, but typical Facebook responses do not provide
that explicit verified-email claim. New Facebook registrations need an
application-specific reviewed verification/linking flow; they are not enabled
safely by setting credentials alone. Already-linked identities can still sign in.
The same review applies when adding another strategy. Do not loosen the verified
claim check to bypass rejected registrations. Review identity links created by
older automatic email-linking code during rollout.

## Set up roles and tenants

### Roles and admin events

```bash
bin/rails generate authify:install --roles --admin
bin/rails db:migrate
```

Assign roles only through trusted operator/application logic. For example, in the
Rails console with the correct user model and tenant context:

```ruby
user = Authify.user_scope.find_by!(email: "owner@example.com")
role = AuthifyRole.find_or_create_by!(name: "admin")
user.authify_roles << role unless user.has_role?(:admin)
```

`user.has_role?(:admin)` checks membership. The event page is
`/authify/admin/authentication_events` and requires the admin role. Roles do not
replace resource-level authorization policies or controlled admin provisioning.

### Tenant isolation: prepare first, activate last

```bash
bin/rails generate authify:install --multi-tenant
bin/rails db:migrate
```

The generated `config/initializers/authify_tenant.rb` reads a trusted
`request.env["authify.tenant_id"]`. Supply that from your own validated organization/
subdomain middleware. Never copy an arbitrary submitted tenant ID into that value.
Configure app-owned tenant associations and foreign keys, backfill every user's
tenant, then generate and review the index conversion:

```bash
bin/rails generate authify:tenant_indexes
# Review the migration before running it.
bin/rails db:migrate
```

Only then set `AUTHIFY_TENANT_ENABLED=true`, restart, run doctor, and test cross-tenant
isolation. Missing context fails closed. Global email uniqueness stays in place
until the explicit index conversion; custom global indexes may need manual review.
Rollback to global uniqueness may be impossible once tenants share email addresses.

Tenant-key changes through `update!` invalidate credentials, even while tenant mode
is disabled. Moving an account requires fresh sign-in and replacement API tokens.
Custom raw-SQL/bulk moves must explicitly invalidate credentials under the user lock.
OAuth provider/UID identities are globally unique; shared membership across tenants
requires an application-specific identity model.

## Configure Kamal deployments

Merge these entries into your existing `config/deploy.yml`; keep the app's current
database/cache/job settings and secrets. Use your own hostnames and public site key:

```yaml
env:
  clear:
    AUTHIFY_ABUSE_MODE: observe
    AUTHIFY_TURNSTILE_SITE_KEY: YOUR_PUBLIC_SITE_KEY
    AUTHIFY_TURNSTILE_HOSTNAMES: app.example.com
    AUTHIFY_WEBAUTHN_ORIGINS: https://app.example.com
    AUTHIFY_WEBAUTHN_RP_ID: app.example.com
  secret:
    - RAILS_MASTER_KEY
    - AUTHIFY_TURNSTILE_SECRET_KEY
```

Provide secret values through Kamal's secret files or supported secret-manager
integration. With destinations, use the corresponding `.kamal/secrets.<destination>`
or shared secrets configuration. Do not commit plaintext secret values. See
[Kamal environment and secret configuration](https://kamal-deploy.org/docs/configuration/environment-variables/).

If Turnstile is wired directly to Rails credentials instead, omit its secret ENV
entry and ensure the matching Rails credential key reaches every worker. A shell
export on your laptop does not change settings inside an existing container.
Run doctor inside the deployed container with its production environment and
secret configuration. Redeploy/restart all relevant workers after configuration changes. Keep observation
mode until staging browser/provider tests succeed, then explicitly select enforcement.

## Test, monitor, and clean up

### Verification commands

After configuring installed features:

```bash
bin/rails authify:version
bin/rails authify:doctor
bin/rails zeitwerk:check
RAILS_ENV=test bin/rails db:prepare
bin/rails test
```

Generated focused tests can be run explicitly when those features are installed:

```bash
bin/rails test \
  test/integration/authify_security_flows_test.rb \
  test/integration/authify_hardening_test.rb \
  test/integration/authify_concurrency_test.rb \
  test/integration/authify_abuse_test.rb
```

OAuth adds `test/integration/authify_oauth_security_test.rb`. PostgreSQL runs the
row-lock concurrency tests; SQLite skips them. Existing app fixtures/routes can
need integration work; passing gem CI does not replace testing your actual app.
Validate real mail delivery, account recovery, MFA, passkey devices, provider outages,
CSRF, shared-network traffic, and tenant isolation before production rollout.

### Observe decisions

Subscribe to `authify.abuse_decision`, `authify.bot_challenge`, and
`authify.abuse_store_error`. A simple development/staging subscriber is:

```ruby
# config/initializers/authify_monitoring.rb
ActiveSupport::Notifications.subscribe("authify.abuse_decision") do |_name, _start, _finish, _id, payload|
  Rails.logger.info("authify action=#{payload[:action]} decision=#{payload[:decision]} reasons=#{Array(payload[:reasons]).join(',')}")
end
```

Monitor challenge rates, successful recovery, false positives, and counter-store
errors. Keep credentials and challenge tokens out of logs. Configure your own
retention policy for authentication events and old session/token records.

### Schedule cleanup

Run these tasks periodically through your scheduler, for example hourly:

```bash
bin/rails authify:prune_abuse
bin/rails authify:prune_challenges
```

For an app already using Solid Queue, equivalent recurring cleanup can be merged
into `config/recurring.yml`:

```yaml
production:
  authify_prune_abuse:
    command: "AuthifyAbuseBucket.where('expires_at < ?', Time.current).delete_all"
    schedule: every hour
  authify_prune_sign_in_challenges:
    command: "AuthifySignInChallenge.where('expires_at < ?', Time.current).delete_all"
    schedule: every hour
  # Include this entry only when passkeys are installed.
  authify_prune_passkey_challenges:
    command: "AuthifyPasskeyChallenge.where('expires_at < ?', Time.current).delete_all"
    schedule: every hour
```

Ensure the scheduler runs and a worker consumes `solid_queue_recurring`. Counter
windows and trusted-browser evidence expire, but rows remain until cleanup. No
Redis dependency is required for these database counters.

### Application-owned security changes

Use `update!` and generated management flows for security changes. Raw SQL,
`update_columns`, and bulk operations bypass Rails callbacks. Custom factor
management must call `user.authify_invalidate_credentials!` under the user lock.
Use `AuthifySession#revoke!` for explicit revocation so it coordinates with enrollment
and session rotation. Upgrade proposals and additive migrations must still be
reviewed; doctor marks configuration validation, not production security approval.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `authify:upgrade` generator not found | Confirm the app's Gemfile uses the intended source, run Bundler, and restart any preloader. |
| Installer says to upgrade first | Run the upgrade preview/application workflow, not another fresh core install. |
| Upgrade conflicts | Review `.authify/upgrade/**/*.proposed`, resolve without merge markers, and rerun. |
| Doctor reports missing security columns/tables | Review and run all generated migrations, including `HardenAuthifyCredentials`. |
| MFA encryption key/decryption error | Use the matching environment credentials and original encryption keys; do not generate replacements over existing data. |
| No verification/reset email | Check provider settings, sender verification, URL host, queued jobs, worker queues, and delivery errors. |
| No Turnstile widget on normal login | Expected in observation mode and low-risk logins; use the controlled staging challenge test. |
| Challenge always rejected | Check site/secret pairing, exact hostname allowlist, action, CSP, backend network access, token reuse, and server ENV after restart. |
| Settings added to credentials have no effect | ENV-based initializers need explicit credentials wiring; see the Turnstile example. |
| Passkey settings return 403 | Confirm identity explicitly; recent sign-in alone is insufficient. |
| Passkey ceremony rejected | Check HTTPS, trusted origin/port, RP ID, supported browser, user verification, and the refreshed CSRF token. |
| Authenticator code rejected after recent use | Wait for the next timestep or use an unused recovery code; codes cannot be replayed. |
| API token stopped working after account changes | Expected credential invalidation; issue a replacement with approved scopes. |
| OAuth rejects an existing matching email or Facebook signup | Review the explicit email-verification and authenticated-linking policy above. |
| Tenant requests return 403 | Check trusted resolver, user backfill, reviewed indexes, activation, and current tenant context. |

## Development and license

For development against a local gem checkout, replace the app's gem entry with
`gem "authify_rails", path: "../authify_rails"`; do not keep a duplicate Git/RubyGems
entry. Gem contributors can run `bundle exec rake test` and build with
`gem build authify_rails.gemspec`.

See [CHANGELOG.md](CHANGELOG.md), [UPGRADING.md](UPGRADING.md), and
[SECURITY.md](SECURITY.md). Authify Rails is available under the MIT License.
