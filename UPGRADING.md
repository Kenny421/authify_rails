# Upgrading Authify Rails

## General process

1. Commit or back up the application.
2. Update the gem.
3. Run `bin/rails generate authify:upgrade`.
4. Review release notes and generated migration requirements.
5. Run `bin/rails db:migrate` when required.
6. Run `bin/rails authify:doctor`.
7. Run the application's complete test suite.
8. Verify sign-in, reset, verification, session revocation, and optional features in staging.

The upgrade generator does not overwrite customized application controllers, views, mailers, or models.

## Security changes

- Two-factor authentication now gates sign-in when enabled. The generated sign-in form includes an `otp_code` field and session creation is blocked if the code is invalid.
- Disabling two-factor authentication now requires both the current password and a valid authenticator code.
- Sudo confirmation now applies a short lockout window after repeated failed password attempts.

If your application customized generated auth views or controllers, merge these safeguards into your local files before deploying.

## From installations without `config/authify.yml`

Run the installer with only the features that already exist, then inspect the generated manifest before accepting new files. For example:

```bash
bin/rails generate authify:install --roles --sudo --skip-bundle
```

Commit the manifest after verifying it accurately represents the application.
# Upgrading generated applications

Run:

```bash
bin/rails generate authify:upgrade
bin/rails db:migrate
bin/rails authify:doctor
bin/rails test
```

The upgrade generator creates additive, guarded migrations for security fields required by newer Authify releases. It does not overwrite generated controllers, models, views, or application customizations. Compare those files with current templates and merge security-flow changes deliberately.
