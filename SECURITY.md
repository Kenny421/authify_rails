# Security Policy

Authentication vulnerabilities should not be reported in a public issue.

Please send a private report to the maintainer with:

- A clear description of the problem
- A minimal reproduction
- The affected Authify, Rails, and Ruby versions
- The expected and actual behavior
- Any suggested mitigation

Do not include real credentials, access tokens, personal data, or production secrets. The maintainer should acknowledge the report, reproduce it, prepare a fix, and coordinate disclosure before publishing details.

Only the latest released minor version is expected to receive security fixes during pre-1.0 development.
# Security posture

Authify generates application-owned authentication code. Production deployments must review generated changes, use HTTPS, configure a shared cache store for rate limits, protect secrets, deliver security mail reliably, monitor authentication events, and maintain database backups.

CI exercises the gem on supported Ruby versions, audits dependencies, generates complete Rails applications, migrates SQLite and PostgreSQL databases, and runs generated integration security tests. OAuth provider responses are tested with mocked OmniAuth payloads; live-provider behavior is outside this repository's automated boundary.

Report suspected vulnerabilities privately to the maintainer. Do not include credentials, personal data, access tokens, or exploitable production details in a public issue.
