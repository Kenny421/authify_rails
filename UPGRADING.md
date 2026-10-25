# Upgrading Authify Rails to 0.4.0

Authify generates application code. Updating the gem alone does not update that code.
Make an application commit and database backup, then test the upgrade in staging.

```bash
bundle update authify_rails
bin/rails generate authify:upgrade --dry-run
bin/rails generate authify:upgrade
# Review the application diff and migration before continuing.
bin/rails db:migrate
bin/rails authify:doctor
bin/rails test
```

The preview does not write files. The upgrade never runs migrations, installs new
optional features, deletes files, or replaces your routes, User model,
ApplicationController, application layout, Gemfile, OAuth credentials initializer,
or branding initializer. These integration files remain application-owned.

## Template comparisons and customizations

The installation manifest records generated template baselines. Upgrade compares
those baselines against the application's current files and the new templates.
Unmodified files can be updated. Non-overlapping customizations are merged with
`git merge-file` (Git must be installed). If Git is unavailable, modifications are
reported as conflicts rather than overwritten.

If any file conflicts, **no application files are updated** and the manifest is
not advanced. Proposed files, including merge markers where applicable, are
written under `.authify/upgrade/` preserving the original directory structure.
Review and resolve the proposed changes into the application, then rerun the
preview and upgrade. Unknown/custom files without a trustworthy baseline require
review. Do not copy a proposal containing conflict markers directly into the app.

Version 0.3.0 templates from repository commit
`b1b49580da4ea7cd6581ae47712e1872e66f97bc` are bundled as immutable comparison data.
Older or independently modified releases do not get guessed baselines. If the
installation manifest is missing, restore it from version control or reconstruct
its version, user_model, views and feature list after inspecting the application;
do not rerun the installer blindly to adopt an unknown installation.

An applied upgrade records `pending_validation` in the manifest's upgrade history.
After migrations and doctor checks pass it becomes `doctor_passed`. Your own tests
and staging checks are still required; doctor does not certify production safety.
Repeated upgrades preserve customizations and do not duplicate the 0.4 migration.

## Schema and rollout

Core migrations add missing authentication columns to an existing user table and
reject incompatible column types. They preserve existing hashes and data. New
fields on existing accounts may require app-specific backfills; accounts without
password hashes cannot use password sign-in. Duplicate case-insensitive email
addresses must be resolved before unique indexes can be added.

The 0.4 migration also adds the TOTP `last_accepted_at` replay-protection field.
Use a maintenance window or coordinated deployment: keep old application workers
serving traffic until migrations have run, then restart all workers on the new
code. Do not serve upgraded TOTP code against an unmigrated database.

These additive security migrations intentionally have no destructive automatic
rollback. Keep the matching previous gem, application commit, and database backup;
review rollback against any data written since deployment.

## Security changes to validate

- Disabled accounts lose existing browser sessions and cannot use API tokens.
- TOTP codes are accepted once per timestep; recovery codes remain single-use.
- Password resets consume the token and revoke sessions transactionally.
- Password changes invalidate outstanding reset links.
- Failed-login increments are protected against concurrent lost updates.
- API tokens require configured scopes and explicit authentication in API controllers.

## Adding features after upgrading

```bash
bin/rails generate authify:install --api --passkeys
bin/rails db:migrate
bin/rails authify:doctor
```

The installed user-model name and view mode are retained. `--all` includes passkeys
and tenant preparation, but passkeys require trusted origins/RP configuration and
tenant mode remains disabled until explicitly configured and backfilled.

See README.md for API, passkey and tenant setup. A tenant resolver and membership
model cannot be inferred safely from an application's existing business logic.

## Adaptive protection follow-up in 0.4.0

Rerun the upgrade preview when updating to the adaptive protection revision. It
adds the `authify_abuse_buckets` model/table, browser challenge partials and assets,
an abuse initializer, controller hooks, tests and a separate guarded
`AddAuthifyAbuseProtection` migration. This works even when the earlier 0.4.0 security
migration has already been applied. Existing initializers/customizations are
compared through the same baseline/conflict process.

Observation mode is the default and preserves the existing fixed controls. Enable
`AUTHIFY_ABUSE_MODE=enforce` only after the migration, challenge-provider configuration,
doctor checks and staging tests. In enforcement mode new failed passwords no longer
extend automatic account-wide lockouts; source/account cooldowns and additional
verification protect the account instead. Existing locks and disabled-account
checks remain authoritative. Review README.md for thresholds, proxy configuration,
monitoring, cleanup and the custom challenge-provider contract.
