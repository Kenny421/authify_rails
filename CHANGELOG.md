# Changelog

## 0.3.0 - Unreleased

- Added friendly authentication routes, starter home page, and accessible flash rendering.
- Added staged TOTP challenges with hashed, single-use recovery codes and secure regeneration.
- Added Google/Facebook OmniAuth identities, mocked callback tests, TOTP enforcement, and authentication-method tracking.
- Added verified-email enforcement and pending email changes with reauthentication, cancellation, notifications, and session revocation.
- Added authenticated password changes, uniform public-endpoint rate limits, and timing-resistant missing-user password checks.
- Added generated Rails integration security tests, SQLite/PostgreSQL CI, Brakeman, dependency auditing, and a Ruby 3.2–3.4 matrix.
- Added guarded upgrade migrations and expanded production checks in `authify:doctor`.
- Added branded multipart HTML and plain-text email layouts.
- Added professional verification, password-reset, welcome, password-changed, and new-sign-in copy.
- Added configurable application name, company name, sender, support address, logo, primary color, and footer.
- Added generated Rails mailer previews for every Authify email.
- Added post-verification welcome messages and password-change/new-sign-in security notifications.
- Expanded the README with email branding, preview, URL-host, and delivery configuration.

## 0.2.0 - Unreleased

- Made `authify:install` rerunnable so optional features can be added later.
- Added `config/authify.yml` installation manifest tracking versions and enabled features.
- Added dependency validation for the admin feature.
- Added `authify:upgrade` reporting generator.
- Added `authify:version` and expanded `authify:doctor` checks.
- Moved sudo elevation state to database-backed Authify sessions.
- Added detailed installation, configuration, security, and upgrade documentation.

## 0.1.0

- Initial core authentication generator.
- Added optional roles, TOTP, API tokens, sudo, admin, and multi-tenant generators.
