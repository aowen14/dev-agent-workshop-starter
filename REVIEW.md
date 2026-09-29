# Review rules: application repo

## What Important means here
- Wrong results returned to a user or API client (off-by-one, bad filter, wrong status code).
- An error path the new code can hit that is not handled or returns a 500.
- A change to an API response, model, or schema that breaks an existing caller.
- Missing input validation on anything user-supplied.
- Auth or permission checks that are missing or bypassable.

## Nits
- At most five. Skip them entirely if there is any Important finding.
- Naming and readability only when it would genuinely confuse the next reader.

## Skip
- Lockfiles (`*.lock`, `pnpm-lock.yaml`, `uv.lock`, `package-lock.json`).
- Generated code, build output, snapshots, and seed or fixture data.
- Formatting, import order, and lint rules CI already enforces.

## Always check
- New or changed endpoints have a test that would fail without the change.
- Pagination, slicing, and index math at the first and last page.
- Errors from I/O, parsing, and external calls are handled or deliberately propagated.
- Any change to an endpoint's params or response shape must update `frontend/src/api/client.ts` and `frontend/src/types.ts` to match. If it does not, that is Important.
