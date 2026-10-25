# Changelog

## 0.4.0 - Unreleased

- Bound browser/API credentials and pending MFA/passkey ceremonies to security
  versions; serialized sign-in completion with password reset and factor changes.
- Added single-use database MFA challenges and atomic per-account verification
  budgets across sessions/IPs; rotated explicit identity proofs for sensitive actions.
- Removed automatic OAuth email linking and ambiguous email-verification claims.
- Added one-time recovery-code responses, reset/resend cooldowns, CSRF renewal,
  local-only return paths, and singular-resource route compatibility.
- Reduced abuse-counter writes to atomic upserts and signal aggregation to one query.
- Added atomic file replacement, failed-write recovery, manifest validation and
  additional replay, concurrency, enrollment and real-CSRF regression coverage.

- Added observe/enforce adaptive authentication protection with shared database
  counters, keyed identifiers, spraying/distributed attack detection, trusted-browser
  evidence, bounded pair cooldowns, and a source resource budget.
- Added opt-in server-verified Turnstile and custom challenge adapters, protected
  registration/reset/resend requests, and cross-IP MFA challenge attempt budgets.
- Added adaptive upgrade migrations, monitoring notifications, cleanup tasks,
  parameter redaction and false-positive/concurrency regression tests.

- Added previewable template-aware upgrades, versioned baselines, conflict proposals,
  repeat-run protection and validation history while preserving application-owned files.
- Added non-destructive existing-user schema preparation and guarded compatibility migrations.
- Fixed disabled-account sessions, reset-token races, reset-link invalidation,
  TOTP replay and concurrent lost login-attempt increments.
- Completed Bearer API authentication, scope allowlists, revocation and tenant checks.
- Added opt-in WebAuthn passkeys with browser controls, user verification,
  single-use expiring challenges and device-management endpoints.
- Added explicitly activated tenant authentication, trusted request resolution and
  a separately reviewed tenant-index conversion generator.
- Added plain views and consistent no-view feature installs; preserved custom model options.
- Fixed SQLite CI setup and OAuth test middleware usage; refreshed audited dependencies.
- Added generated behavior/concurrency tests and an actual 0.3.0 upgrade smoke workflow.
- Removed Windows download metadata from packaged/generated files.

## 0.3.0

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
