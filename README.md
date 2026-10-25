# Authify Rails

Authify Rails installs secure, editable authentication into a Rails 8 application with one generator. The default installation provides a complete browser-authentication foundation, while optional features can be added together during the first install or later by rerunning the same generator.

> Status: pre-1.0. Review generated code and test it in your application before production use.

## What Authify installs

The basic command installs:

- User registration
- Email and password sign-in
- A staged two-factor sign-in challenge shown only to users with active 2FA
- Sign-out and remember-me sessions
- Password reset with single-use digested tokens
- Authenticated password changes with current-password confirmation and global session revocation
- Email verification
- Verification enforcement that blocks sign-in and revokes sessions until the email is verified
- Safe email changes that remain pending until the new address is verified
- Sensitive email-change confirmation, rate limits, cancellation, security notifications, and session revocation
- Database-backed session and device management
- Idle and absolute session expiration
- Session revocation
- Login failure tracking and temporary account lockout
- Authentication event logging
- `bcrypt` password hashing through `has_secure_password`
- Pwned Passwords checking through the k-anonymity range API
- Editable mailers and views
- Accessible notice and alert rendering in the application layout
- A starter `HomeController#index` page and root route when the app does not already have them
- Tailwind-ready responsive pages
- `authify:doctor` and `authify:version` tasks
- An installation manifest at `config/authify.yml`

Optional features:

- `--oauth` — Google and Facebook sign-in, with support for other OmniAuth providers
- `--roles` — simple role assignments
- `--two-factor` — TOTP authenticator-app enrollment with single-use recovery codes
- `--api` — digested personal API tokens, Bearer authentication and explicit scopes
- `--sudo` — step-up authentication for sensitive actions
- `--admin` — authentication-event administration page; requires roles
- `--passkeys` — WebAuthn registration, sign-in, management and browser controls
- `--multi-tenant` — tenant preparation with explicit activation and a trusted resolver
- `--all` — all optional features

## Requirements

- Ruby 3.2 or newer
- Rails 8.0 or newer
- Active Record
- A Rails application using cookies for browser sessions

Authify currently targets Rails 8 migrations. Confirm compatibility before using it with another Rails version.

## Upgrading an existing installation

Read [UPGRADING.md](UPGRADING.md) before updating an existing app. Version 0.4.0
adds a read-only preview and template-aware merge process:

```bash
bin/rails generate authify:upgrade --dry-run
bin/rails generate authify:upgrade
```

Conflicts block all application-file updates and produce reviewable proposals.
Custom branding and integration files remain application-owned. New installs stop
before writes when common existing authentication integrations or route conflicts
are detected; review those migrations explicitly.

## Installation

Add the gem:

```ruby
gem "authify_rails"
```

For local development:

```ruby
gem "authify_rails", path: "../authify_rails"
```

Then run:

```bash
bundle install
bin/rails generate authify:install
bin/rails db:migrate
bin/rails authify:doctor
```

The default installation adds `bcrypt` to the host application's Gemfile and runs `bundle install`. Use `--skip-bundle` when dependency installation is managed separately.

### Google and Facebook sign-in

Install OAuth support at initial setup or add it later:

```bash
bin/rails generate authify:install --oauth
bin/rails db:migrate
```

The generator installs OmniAuth, its Rails CSRF protection, and the Google and Facebook strategies. Set these environment variables:

```text
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
FACEBOOK_APP_ID
FACEBOOK_APP_SECRET
```

Register these callback URLs with the providers, replacing the host with your application's HTTPS origin:

```text
https://example.com/auth/google_oauth2/callback
https://example.com/auth/facebook/callback
```

Authify creates an `AuthifyOauthIdentity` for each provider account. A returning user is found by provider and provider UID. A new identity is linked to an existing email account, or creates an account, only when the provider reports that the email is verified. Provider authorization starts with POST requests protected by `omniauth-rails_csrf_protection`.

To add GitHub, Microsoft, or another provider, add its OmniAuth strategy gem and a `provider` entry in `config/initializers/authify_oauth.rb`. The generated callback and identity model are provider-agnostic; providers that do not expose verification in `extra.raw_info.email_verified` or `extra.raw_info.verified` need an application-specific verification rule.

## Recommended rollout

For most browser-first Rails applications, use this sequence:

1. Start with core plus two-factor and sudo mode:

```bash
bin/rails generate authify:install --two-factor --sudo
bin/rails db:migrate
bin/rails authify:doctor
```

2. Add roles only when authorization tiers are real product needs:

```bash
bin/rails generate authify:install --roles
bin/rails db:migrate
```

3. Add admin after roles are present (`--admin` requires role support):

```bash
bin/rails generate authify:install --admin
bin/rails db:migrate
```

4. Add API tokens only for applications that expose token-based access:

```bash
bin/rails generate authify:install --api
bin/rails db:migrate
```

5. Add multi-tenant support only when the application already uses tenant-scoped data:

```bash
bin/rails generate authify:install --passkeys
--multi-tenant
```

After enabling `--multi-tenant`, wire tenant associations and add tenant indexes manually to match the data model.

## Production readiness checklist

Before going live, complete the following in the host Rails app:

1. Run install, migrate, and doctor:

```bash
bin/rails generate authify:install --two-factor --sudo
bin/rails db:migrate
bin/rails authify:doctor
```

2. Enforce transport security in production:

```ruby
# config/environments/production.rb
config.force_ssl = true
```

3. Configure mailer host and sender for security links and alerts:

```ruby
# config/environments/production.rb
config.action_mailer.default_url_options = { host: "app.example.com" }
```

```ruby
# config/initializers/authify.rb
Authify.configure do |config|
  config.mailer_from = "security@app.example.com"
  config.support_email = "support@app.example.com"
end
```

4. Keep security notifications enabled unless there is a strong reason not to:

```ruby
config.email_notifications_enabled = true
config.new_sign_in_notifications = true
config.password_change_notifications = true
```

5. If two-factor is enabled, verify login and disable flows in staging:

- Sign-in should require password plus authenticator code for users with active 2FA.
- Disabling 2FA should require current password plus authenticator code.

6. Verify lockout and session controls:

- Repeated failed sign-in attempts trigger account lockout.
- Sudo challenge applies temporary lockout after repeated failures.
- Revoking sessions from account sessions view signs devices out.

7. Ensure your deployment process runs app tests and `bin/rails authify:doctor` on every release.

## Installing multiple features

Flags can be combined in a single command:

```bash
bin/rails generate authify:install \
  --roles \
  --two-factor \
  --api \
  --sudo \
  --admin
```

Install every optional feature:

```bash
bin/rails generate authify:install --all
```

`--admin` requires role management, so use it with `--roles` unless roles are already installed.

## Adding features later

The installer is designed to be rerun. Authify reads `config/authify.yml`, skips features already installed, and generates only missing requested features.

Start with the basics:

```bash
bin/rails generate authify:install
```

Add sudo mode and roles later:

```bash
bin/rails generate authify:install --sudo --roles
bin/rails db:migrate
```

Add API tokens later:

```bash
bin/rails generate authify:install --api
bin/rails db:migrate
```

Do not delete `config/authify.yml`; it records the installed Authify version, user model, view style, and enabled features.

## Generator options

```text
--user-model=User
--views=tailwind|plain|none
--oauth
--roles
--two-factor
--api
--sudo
--admin
--multi-tenant
--all
--skip-bundle
```

Custom user model example:

```bash
bin/rails generate authify:install --user-model=Account
```

When the model already exists, Authify injects its authentication concerns rather than replacing the model file. Review the generated migration: missing authentication columns are added while incompatible types require manual resolution.

For a new application, the installer creates `HomeController#index`, its view, and `root "home#index"`. Existing home files and existing root routes are preserved.

## Generated routes

The core installer adds routes equivalent to:

```ruby
scope module: :authify do
  get "/sign-in", to: "sessions#new", as: :new_session
  post "/sign-in", to: "sessions#create", as: :session
  delete "/sign-out", to: "sessions#destroy", as: :sign_out
  get "/sign-up", to: "registrations#new", as: :new_registration
  post "/sign-up", to: "registrations#create", as: :registration
  get "/forgot-password", to: "passwords#new", as: :new_password
  post "/forgot-password", to: "passwords#create", as: :passwords
  get "/reset-password/:token", to: "passwords#edit", as: :edit_password
  patch "/reset-password/:token", to: "passwords#update", as: :password
end
```

Typical paths:

```text
/sign-in
/sign-up
/sign-out
/forgot-password
/reset-password/:token
/account/password
/verify-email
/account/sessions
```

Optional generators append their own routes.

OAuth support additionally handles:

```text
/auth/:provider/callback
/auth/failure
```

## Protecting controllers

Authify includes its authentication concern in `ApplicationController`.

Require authentication:

```ruby
class DashboardController < ApplicationController
  require_authentication
end
```

Protect selected actions:

```ruby
class ProfilesController < ApplicationController
  require_authentication only: %i[edit update]
end
```

Available controller helpers include:

```ruby
current_user
authenticated?
```

Unauthenticated users are redirected to the sign-in page, and safe GET destinations are remembered for the post-login redirect.

## Sudo / step-up authentication

Install sudo mode:

```bash
bin/rails generate authify:install --sudo
bin/rails db:migrate
```

Protect sensitive actions:

```ruby
class Account::PasswordsController < ApplicationController
  require_authentication
  require_sudo only: %i[edit update]
end
```

Require a recently completed challenge:

```ruby
require_sudo freshness: 2.minutes, only: :destroy
```

Sudo state is stored on the current `AuthifySession` using `sudoed_at`, `sudo_expires_at`, and `sudo_method`. The default validity window is ten minutes.

Good sudo-protected actions include:

- Changing email or password
- Deleting an account
- Disabling two-factor authentication
- Viewing recovery codes
- Creating API tokens
- Changing roles or permissions

## Password security

Generated user models include:

```ruby
include Authify::Authenticatable
include Authify::SecurePassword
```

Authify uses Rails `has_secure_password` and `bcrypt`. Defaults:

```ruby
config.password_minimum_length = 12
config.password_maximum_length = 128
config.pwned_password_check = true
config.pwned_fail_closed = false
config.pwned_timeout = 3.seconds
```

The breach checker hashes the password with SHA-1 locally, sends only the first five hash characters to the Pwned Passwords range API, and compares suffixes locally. The plain password is never sent.

The checker fails open by default during network outages so registration is not blocked. Applications with strict availability requirements may choose fail-closed behavior.


## Branded authentication emails

The basic installer generates polished multipart email templates. Every message has responsive HTML, a plain-text fallback, application branding, support details, safe security wording, and a copyable fallback link where appropriate.

Generated messages:

- Email-address verification
- Password reset
- Welcome after successful verification
- Password-changed security alert
- New sign-in security alert

Generated files include:

```text
app/mailers/authify_mailer.rb
app/views/layouts/authify_mailer.html.erb
app/views/layouts/authify_mailer.text.erb
app/views/authify_mailer/*.html.erb
app/views/authify_mailer/*.text.erb
test/mailers/previews/authify_mailer_preview.rb
```

Configure branding in `config/initializers/authify.rb`:

```ruby
Authify.configure do |config|
  config.app_name = "Acme Portal"
  config.company_name = "Acme Incorporated"
  config.mailer_from = "security@acme.example"
  config.support_email = "support@acme.example"
  config.logo_url = "https://acme.example/logo-email.png"
  config.primary_color = "#2563eb"
  config.email_footer_text = "You received this security message because you have an Acme account."
end
```

`logo_url` must be an absolute URL that an email client can load. Keep the image small and host it over HTTPS. Email styling uses inline CSS for broad mail-client compatibility and does not depend on the application's Tailwind build.

Security notification controls:

```ruby
config.email_notifications_enabled = true
config.new_sign_in_notifications = true
config.password_change_notifications = true
```

New sign-in alerts are enabled by default. An alert is sent only when both the IP address and device user-agent have not appeared in any prior successful sign-in for the user. A known IP or a known device suppresses the alert.

### Previewing emails

In development, open Rails' standard mailer-preview interface:

```text
/rails/mailers/authify_mailer
```

The preview uses the first user record when available and otherwise builds a non-persisted sample user. Configure `default_url_options` before testing links:

```ruby
# config/environments/development.rb
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }
```

Production example:

```ruby
config.action_mailer.default_url_options = { host: "app.example.com", protocol: "https" }
```

Authify queues messages with `deliver_later`; make sure Active Job is connected to a working queue adapter in production.

## Sessions

The browser receives an encrypted, HTTP-only cookie containing a random opaque token. The database stores only its SHA-256 digest.

Default session settings:

```ruby
config.session_idle_timeout = 30.minutes
config.session_absolute_timeout = 30.days
config.remember_me_duration = 30.days
```

Normal browser sessions expire after the configured idle timeout. Remembered sessions use a persistent cookie and bypass the idle timeout, but still expire after `remember_me_duration`. Revocation, password changes, email changes, disabled accounts, and verification enforcement continue to invalidate remembered sessions.

The generated cookie uses:

```ruby
httponly: true
secure: Rails.env.production?
same_site: :lax
```

Password resets revoke all existing Authify sessions.

## Configuration

The installer creates `config/initializers/authify.rb`:

```ruby
Authify.configure do |config|
  config.user_class_name = "User"
  config.password_minimum_length = 12
  config.password_maximum_length = 128
  config.pwned_password_check = true
  config.pwned_fail_closed = false
  config.email_verification_required = true
  config.session_idle_timeout = 30.minutes
  config.session_absolute_timeout = 30.days
  config.remember_me_duration = 30.days
  config.sudo_timeout = 10.minutes
  config.after_sign_in_path = "/"
  config.after_sign_out_path = "/"
end
```

## Mailer setup

Configure a host so verification and reset links are generated correctly:

```ruby
# config/environments/production.rb
config.action_mailer.default_url_options = {
  host: "example.com",
  protocol: "https"
}
```

Configure a delivery provider separately. Authify generates editable HTML templates in `app/views/authify_mailer`.

In development, do not copy verification or reset links from Rails' raw mail log. Email bodies are quoted-printable encoded, and long URLs may be wrapped with `=` as a soft line-break marker; copying one physical log line truncates the token. Open the message through a real mail client or a development inbox such as Letter Opener, Mailpit, or Mailcatcher. If a link was copied from the log, request a fresh message and use the complete decoded URL.

## Two-factor authentication

Install TOTP support:

```bash
bin/rails generate authify:install --two-factor
bin/rails db:migrate
```

This adds `rotp` and `rqrcode`, an encrypted TOTP secret, enrollment controller, QR code page, and enable/disable routes.

Recovery codes are generated when 2FA is enabled, displayed once, stored only as digests, and consumed atomically. Regenerating codes requires the current password and a valid authenticator code and invalidates every previous recovery code.

## API tokens

Install personal token support:

```bash
bin/rails generate authify:install --api
bin/rails db:migrate
```

HTTP token creation requires `current_password` plus `code` when MFA is enabled, or a recent explicit identity confirmation. Password resets, password/email changes and factor changes invalidate previously issued tokens. Raw tokens are returned only when created. The database stores the token digest. Add application-specific scopes and authorization rules before exposing protected API endpoints.

## Roles and administration

Install role support:

```bash
bin/rails generate authify:install --roles
bin/rails db:migrate
```

Check a role:

```ruby
current_user.has_role?(:admin)
```

The optional admin event page requires `has_role?(:admin)`. Authify roles are intentionally small; use Pundit, Action Policy, or application policies for full authorization.

## Multi-tenancy

In 0.3.0 the `--multi-tenant` option generated a starting concern; see the 0.4.0 tenant section below for the current workflow. Authify cannot infer whether the tenant is a school, organization, account, subdomain, or request context, so you must add the correct association, foreign key, composite unique index, and tenant-resolution logic.

Never rely only on a model validation for tenant isolation. Enforce database indexes and scope every authentication lookup to the current tenant.

## Diagnostics

Run:

```bash
bin/rails authify:doctor
```

The doctor checks models, password hashing, routes, mailer setup, secret key base, manifest presence, and production HTTPS/mailer host configuration.

Show version and installed features:

```bash
bin/rails authify:version
```

## Upgrading

After updating the gem:

```bash
bundle update authify_rails
bin/rails generate authify:upgrade
bin/rails authify:doctor
bin/rails test
```

The upgrade generator previews template changes, preserves non-overlapping customizations, and blocks application updates when conflicts require review. Review [UPGRADING.md](UPGRADING.md) for release-specific instructions.

## Security notes

Before production deployment:

- Use a maintained Ruby release (Ruby 3.4 or newer is recommended); Ruby 3.2 compatibility tests do not make that end-of-life runtime suitable for production
- Use HTTPS and enable `config.force_ssl`
- Configure mail delivery and URL options
- Review every generated migration
- Apply database uniqueness indexes
- Keep OAuth authorization on POST requests; review verified-email claims and existing provider identity links
- Add rate limiting at the application or edge layer
- Add authorization policies beyond authentication
- Protect sensitive actions with sudo mode
- Test account enumeration and redirect behavior
- Run your application's security scanners
- Keep Rails and Authify updated
- Use a shared production Rails cache store so controller rate limits are enforced consistently across processes

Email changes require explicit recent identity confirmation, or the current password plus an enrolled authenticator/recovery code. The current address remains active until the new address is confirmed. Authify rate-limits requests and confirmations, notifies the old address when a change is requested, notifies both addresses after confirmation, supports cancellation, and revokes all sessions after the address changes.

Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md).

## Development

```bash
bundle install
bundle exec rake test
```

Build the gem:

```bash
gem build authify_rails.gemspec
```

## License

Authify Rails is available under the MIT License.


## API authentication in 0.4.0

Declare allowed scopes in your Authify initializer before issuing tokens:

```ruby
config.api_scopes = %w[books:read books:write]
```

A resource controller can authenticate without browser cookies:

```ruby
class Api::BooksController < ActionController::API
  include Authify::ApiAuthentication
  require_api_scope "books:read"

  def index
    render json: Current.user.books
  end
end
```

Send `Authorization: Bearer authify_live_...`. Missing, expired, revoked,
unverified-account, disabled-account, wrong-tenant and no-longer-approved-scope
tokens are rejected. Missing resource scopes return 403. All listed scopes are
required. Tokens are returned in full only on creation; stored values are digests.
The generated token-management controller still uses browser authentication and
CSRF protection. Use `AuthifyApiToken.issue!(..., expires_at: 30.days.from_now)`
when issuing expiring tokens programmatically. Existing scopes must be explicitly
included in the configuration; an empty allowlist only permits unscoped tokens.

## Passkeys in 0.4.0

```bash
bin/rails generate authify:install --passkeys
bin/rails db:migrate
```

Configure explicit trusted origins and the RP ID:

```text
AUTHIFY_WEBAUTHN_ORIGINS=https://app.example.com
AUTHIFY_WEBAUTHN_RP_ID=app.example.com
```

Local development defaults to `http://localhost:3000` and RP ID `localhost`.
Production has no permissive defaults. Use a current browser supporting
`PublicKeyCredential.parseCreationOptionsFromJSON`,
`parseRequestOptionsFromJSON` and credential `toJSON()`; HTTPS is required except
for localhost. The generator adds a passkey sign-in button and `/passkeys` settings.
Enrollment/deletion requires an explicit recent identity confirmation: current
password plus an enrolled authenticator/recovery code, or a fresh assertion from
an existing passkey. A newly created login session alone does not grant this
permission. The settings page supports both confirmation methods. Confirmation
rotates the session; JSON clients must replace their CSRF token with the
`X-CSRF-Token` response header, as the generated browser script does.
WebAuthn verifies origin, RP ID, signature, user verification and counters;
database-backed challenges expire after five minutes and are consumed once even
for authenticators whose counter is zero. These are passwordless passkeys with
required local user verification; they do not prompt for a second TOTP code.
Schedule `bin/rails authify:prune_challenges` periodically to remove expired rows.
Keep a separate recovery method and test with real target devices before rollout.
No existing login method is removed when passkeys are installed.

## Tenant authentication in 0.4.0

```bash
bin/rails generate authify:install --multi-tenant
bin/rails db:migrate
```

The generated `config/initializers/authify_tenant.rb` leaves tenant mode disabled.
Configure `tenant_resolver` from trusted organization/subdomain middleware, backfill
every user's `tenant_id`, and configure app-owned tenant associations/foreign keys.
Do not trust a submitted tenant parameter. The default resolver reads
`request.env["authify.tenant_id"]`; your middleware must populate it.

After backfilling, explicitly generate and review the constraint conversion:

```bash
bin/rails generate authify:tenant_indexes
# Review: this replaces global email indexes with tenant-scoped unique indexes.
bin/rails db:migrate
```

Set `AUTHIFY_TENANT_ENABLED=true` only after configuring and testing the resolver.
Missing tenant context fails closed. Registration, password sign-in/reset, email
verification/change, sessions, API tokens, passkeys and user-linked admin events
are scoped to the resolved tenant. Unknown-account events without a user are not
shown in tenant-scoped admin listings. OAuth identities are currently globally
unique by provider/UID and cannot be linked into another tenant; shared-identity
membership across tenants needs an application-specific account model.

Global uniqueness constraints are preserved until you explicitly run the reviewed
conversion migration. Custom global unique indexes may also need manual conversion.
Rollback to global indexes can fail once tenants share an email address, so there
is no automatic destructive rollback. A later security upgrade preserves named
tenant email indexes instead of reintroducing global constraints.

## Adaptive login and bot protection

Adaptive protection uses shared database counters for password sign-in, registration,
password-reset requests and verification-email resends. It detects repeated
source/account failures, distributed failures against an account, and password
spraying across accounts. It does not identify humans with certainty or replace
edge-level DDoS protection.

The default is **observation mode**. Existing rate limits and account lockouts remain
in effect while `authify.abuse_decision` notifications report the projected decision.
No third-party challenge script is loaded unless a challenge is needed and a provider
has been configured.

To upgrade existing generated files and add the counter table:

```bash
bin/rails generate authify:upgrade --dry-run
bin/rails generate authify:upgrade
# Review the diff and additive migration first.
bin/rails db:migrate
bin/rails authify:doctor
bin/rails test
```

### Configure a verified bot challenge

The generated `config/initializers/authify_abuse.rb` supports Cloudflare Turnstile:

```text
AUTHIFY_ABUSE_MODE=observe
AUTHIFY_TURNSTILE_SITE_KEY=your_public_widget_site_key
AUTHIFY_TURNSTILE_SECRET_KEY=your_server_secret
AUTHIFY_TURNSTILE_HOSTNAMES=app.example.com
```

Register the same hostnames in your Turnstile widget. Allow
`https://challenges.cloudflare.com` in the application's CSP script/frame rules,
and allow the Rails backend to reach Cloudflare's Siteverify endpoint. Keep the
secret server-side. The adapter checks success, exact request hostname against a
configured allowlist, and the expected action. Cloudflare validates expiration and
single use; failed, duplicate, invalid, mismatched and unavailable responses do not
approve a login. See [Cloudflare's validation documentation](https://developers.cloudflare.com/turnstile/get-started/server-side-validation/).

For a custom provider, configure `bot_challenge_partial` and a
`bot_challenge_verifier` callable accepting `token:`, `request:` and `action:`.
The partial must submit `authify_challenge_token` inside the existing form. The
verifier must perform server-side, single-use validation and return exactly `true`
only after validating the expected action and deployment origin. Browser-supplied
success flags are never accepted.

### Enable enforcement after observing real traffic

Set `AUTHIFY_ABUSE_MODE=enforce` after testing the challenge and recovery paths in
staging. `authify:doctor` checks that the shared counter table and challenge setup
exist. A correctly configured provider and real-device/browser tests are still
required; configuration checks cannot certify a provider's availability.

In enforcement mode:

- Occasional password mistakes remain ordinary login failures.
- Repeated failures introduce challenge/MFA requirements, then a bounded
  source/account cooldown with `Retry-After`; requests blocked by that cooldown do
  not keep extending its last-failure time.
- Automatic new password-failure account-wide locks are replaced with these
  controls. Pre-existing `locked_until` values are still honored until expiration.
- Correct passwords still require any enrolled MFA. Under elevated risk, a correct
  password without MFA needs a verified bot challenge. Passkey sign-in remains a
  separate cryptographically verified path.
- A previously verified browser can reduce soft challenges caused by distributed
  or shared-IP attacks. Its opaque encrypted cookie is never sufficient to sign
  in and cannot bypass repeated failures against its own source/account pair.
- MFA allows five submissions per primary-authentication challenge and ten per
  account in a fixed five-minute window across IPs and newly minted challenges.
  At most twenty challenges can be issued per account in that window. Explicit
  sensitive-action confirmations allow ten submissions per account per five-minute
  window. These intrinsic verification limits apply in every adaptive mode and
  fail closed if shared storage is unavailable. Rejected requests do not extend
  the fixed window. Accounts under an active attack may need to wait until the
  next window or use an available passkey/recovery path.
- Successful password changes, resets and email changes invalidate the affected
  account's trusted-browser evidence. Failed attacks do not revoke existing sessions.
- The source request hard budget protects application resources and can still
  restrict shared networks under extreme load. Tune it from observed traffic.

Modes are `off`, `observe` and `enforce`. `off` disables adaptive tracking while
retaining legacy authentication controls. Invalid mode names and invalid numeric
settings are rejected. Thresholds are configurable through `Authify.configure`:

```ruby
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
```

Configure Rails' trusted proxy list correctly before relying on `request.remote_ip`;
never treat arbitrary public forwarding headers as authoritative. All workers must
share the counter database and the same Rails key material. Missing counter storage
fails closed for enforced password/public attempts; observation retains existing
controls and emits `authify.abuse_store_error` notifications.

### Monitoring and retention

Subscribe to `authify.abuse_decision`, `authify.bot_challenge` and
`authify.abuse_store_error` through `ActiveSupport::Notifications`. Monitor challenge
rates, successful recovery and false positives before changing thresholds. The
counter table stores keyed hashes of account/source/browser identifiers, not raw
emails, IPs, passwords or challenge tokens. Account identifiers include tenant
context. Minute buckets expire shortly after the configured window; trusted-browser
records expire after the configured lifetime.

Schedule `bin/rails authify:prune_abuse` periodically (for example hourly through
Solid Queue recurring tasks). There is no Redis requirement. The generated abuse
initializer adds sensitive challenge/credential fields to Rails parameter filtering.
Existing application authentication-event retention remains application-owned.


### Credential changes and OAuth identities

Password, email, verification and disabled-state changes advance a database-backed
security version. MFA/passkey changes do the same. Earlier browser sessions,
API tokens and unfinished MFA/passkey sign-ins cannot regain validity. Factor
management rotates the verified current session and invalidates other sessions
and API tokens; recreate affected API integrations after such changes. Use model
`update!`/the generated management flows for security changes: raw SQL,
`update_columns` and bulk updates bypass Rails security callbacks. Custom factor
management must call `user.authify_invalidate_credentials!` under the user lock.

New OAuth identities require an explicit boolean `email_verified: true` from the
trusted provider. A generic account `verified` flag or string value is insufficient.
An existing account is never linked automatically by matching email, including an
unverified local account. Already-linked identities can still sign in. Authenticated
provider linking is not implemented; do not bypass these checks to add it. Providers
that do not supply an explicit verified-email claim, including typical Facebook
responses, need a separately reviewed email-verification/linking flow before new
registrations can be accepted. Review identities created by earlier automatic
email-linking code during rollout.

Password-reset and verification resends have an atomic sixty-second cooldown;
repeat requests retain the first usable link. Recovery codes appear once in the
successful response, with `Cache-Control: no-store`, and are never put in cookies.
The session settings page shows the most recent 100 records. Expired records still
need an application retention policy and scheduled cleanup.
