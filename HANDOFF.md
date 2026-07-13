# Handoff: pubsub.pulsar mTLS contribution

> Context file for continuing this work in a new codespace/session.
> Lives on branch `handoff-notes` ONLY — never merge into `pubsub-pulsar-mtls`.
> Contribution is made as an INDIVIDUAL (personal GitHub account); keep any
> employer names/internals out of all public text (issue, PR, commits, comments).

## State (2026-07-13)

Branch `pubsub-pulsar-mtls` on `bharatbhushan1705/components-contrib`, two commits:

- `f769251d` — the feature: `tlsCertFile` / `tlsKeyFile` (client-cert auth via
  `pulsar.NewAuthenticationTLS`) plus `tlsTrustCertsFilePath` / `tlsValidateHostname`
  in `pubsub/pulsar/{metadata.go,pulsar.go,metadata.yaml}` + 4 unit tests.
  Auth precedence: token → oauth2 → client cert. Parse-time validation:
  cert and key must be set together.
- `843c0c3b` — `Auth:mTLS` certification scenario in
  `tests/certification/pubsub/pulsar/`: `config/docker-compose_auth-mtls.yaml`
  (standalone 3.0.0, `tlsRequireTrustedClientCertOnConnect=true`,
  `AuthenticationProviderTls`, `anonymousUserRole=anonymous`),
  `components/auth-mtls/` (10 consumer specs, `pulsar+ssl://localhost:6651`),
  committed 10-year test certs + `config/certs/generate.sh`.

Verification, all green on 2026-07-13:
- `go test ./pubsub/pulsar` — unit tests pass, gofmt clean, metadata bundle validates.
- Full certification suite, all three auth phases in ONE run:
  `--- PASS: TestPulsar (2401.46s)` — Auth:None 16/16, Auth:mTLS 16/16,
  Auth:OAuth2 18/18, zero failures. (Run from `tests/certification/pubsub/pulsar`
  with `go test -v -timeout 90m`; ~40 min on 2 cores.)

## Next steps (in order)

1. **Post the proposal issue** on dapr/components-contrib (draft below).
2. **Open the PR** from `bharatbhushan1705/components-contrib:pubsub-pulsar-mtls`
   → `dapr/components-contrib:master`, linking the issue (draft below).
3. **dapr/docs companion PR** documenting the four new metadata fields on the
   Pulsar pubsub component page
   (`daprdocs/content/en/reference/components-reference/supported-pubsub/setup-pulsar.md`
   in the dapr/docs repo).
4. **Respond fast to review feedback** — the stale-bot marks PRs stale after
   30 days of silence and closes 7 days later. The prior attempt (#3270) died
   this way after its certification tests failed; ours pass, which was the
   whole point of step-by-step verification.

## Issue draft

**Title:** `pubsub.pulsar: support client certificate (mTLS) authentication`

**Body:**

The built-in `pubsub.pulsar` component supports token and OAuth2 authentication,
but not TLS client-certificate (mTLS) authentication, even though
`pulsar-client-go` supports it natively via `pulsar.NewAuthenticationTLS`.
Brokers configured with `AuthenticationProviderTls` and
`tlsRequireTrustedClientCertOnConnect=true` (a common enterprise setup) are
unreachable from Dapr today without a custom pluggable component.

Related: #3269 and #1860 (asks for Pulsar TLS options), and PR #3270 (a prior
attempt at TLS options that went stale on failing certification tests).

**Proposal** — four new metadata fields, matching pulsar-client-go's
`ClientOptions`:

- `tlsCertFile` / `tlsKeyFile` — client certificate + key; presence of a cert
  selects `AuthenticationTLS` (precedence stays token → oauth2 → client cert;
  setting one of the pair without the other is a config error)
- `tlsTrustCertsFilePath` — custom CA bundle for verifying the broker
- `tlsValidateHostname` — hostname verification toggle

I have a working implementation with unit tests, plus a new `Auth:mTLS`
certification scenario (standalone broker with
`tlsRequireTrustedClientCertOnConnect=true`) — the full certification suite
(Auth:None, Auth:OAuth2, Auth:mTLS) passes. Happy to open the PR.

## PR description draft

**Title:** `feat(pubsub/pulsar): add client certificate (mTLS) authentication`

**Body:**

## Description

Adds TLS client-certificate (mTLS) authentication to the `pubsub.pulsar`
component, wiring `pulsar-client-go`'s `NewAuthenticationTLS` behind four new
metadata fields:

| Field | Purpose |
|---|---|
| `tlsCertFile` | client certificate (PEM) |
| `tlsKeyFile` | client private key (PEM, PKCS#8) |
| `tlsTrustCertsFilePath` | CA bundle for verifying the broker |
| `tlsValidateHostname` | broker hostname verification (default false) |

Design points:
- Existing auth precedence is preserved: token → OAuth2 → client certificate.
  Nothing changes for existing users.
- `tlsCertFile`/`tlsKeyFile` must be set together; setting only one fails at
  Init with a clear error.
- `metadata.yaml` gains a "Client certificate (mTLS)" authentication profile;
  the two trust-related fields are general TLS options usable with any profile.

Also adds an `Auth:mTLS` certification scenario mirroring the existing
`auth-none`/`auth-oauth2` layout: a standalone broker with
`authenticationProviders=AuthenticationProviderTls` and
`tlsRequireTrustedClientCertOnConnect=true`, self-signed 10-year test
fixtures with a `generate.sh` to regenerate them. Two setup subtleties worth
noting for reviewers (both are why the scenario is strict): TLS listener ports
must be set via `PULSAR_PREFIX_`-prefixed env vars (they are absent from
`standalone.conf`, so `apply-config-from-env.py` ignores the bare names), and
cert fixtures are committed world-readable because the container runs as
uid 10000.

## Issue reference

Closes #<issue-number-from-step-1>. Related: #3269, #1860, #3270.

## Checklist

- [x] Code compiles correctly
- [x] Created/updated tests — 4 new unit tests; full certification suite
      (Auth:None + Auth:OAuth2 + new Auth:mTLS) passes:
      `--- PASS: TestPulsar (2401.46s)`, 50 sub-verdicts, 0 failures
- [x] Extended the documentation — `metadata.yaml` updated; dapr/docs
      companion PR to follow

## Operational gotchas (for whoever runs the tests)

- Certification suite: run from `tests/certification/pubsub/pulsar`,
  `go test -v -timeout 90m` (full) or `-run "TestPulsar/Auth:mTLS"` (~12 min).
  Needs Docker + the hyphenated `docker-compose` binary on PATH.
- Host ports 6650/6651/8080 must be free — instant sub-second failures on
  every subtest mean compose-up failed (usually a port conflict), not a code bug.
- Codespace idle-suspend kills long runs; orphaned test containers then
  crash-loop (restart policies) — `docker rm -f` them before relaunching.
- Never `pkill -f "go test"` — the pattern can match your own monitor shells.
- Commits need DCO sign-off (`git commit -s`) with the personal identity.
- Pushes from a codespace: the default GITHUB_TOKEN may be repo-scoped;
  this clone used `credential.helper '!env -u GITHUB_TOKEN gh auth git-credential'`
  after a `gh auth login` device flow, and pushed with
  `env -u GITHUB_TOKEN git push fork <branch>`.
