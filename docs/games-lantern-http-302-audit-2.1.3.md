# Games Lantern HTTP 302 audit — BetterInventory 2.1.3

## Incident

The supplied `Gamelanterns auto-crafter.txt` records two identical failures:

```text
Games Lantern transport event=transport_failed status=302 reason=transport_http_status
Games Lantern import failed: transport_http_status
```

There is no BetterInventory Lua exception or game crash at this boundary. The log continues normally until the user closes Darktide.

## Root cause

Clipboard handling intentionally converts a copied Games Lantern build URL into the canonical UUID-only form:

```text
https://darktide.gameslantern.com/builds/<uuid>
```

Games Lantern currently responds to this endpoint with HTTP 302 and redirects to:

```text
https://darktide.gameslantern.com/builds/<same-uuid>/<build-slug>
```

The Windows curl adapter already followed HTTPS redirects. The Wine/Proton adapter did not pass curl `--location`, so every canonical build request terminated at the expected 302 before HTML parsing. This explains why the feature worked on Windows but consistently failed for the reporting Linux user.

## Remediation

- Both platform adapters now use `--location`, `--max-redirs 3`, and HTTPS-only initial/redirect protocol allowlists.
- Both adapters return curl's final `url_effective` alongside status and content type.
- The coordinator accepts only the original canonical URL or a bounded lowercase slug under the exact same host and build UUID. A cross-host, changed-UUID, query, fragment, malformed, or oversized slug fails closed as `transport_redirect_target`.
- The original total/connect timeouts, two-MiB body cap, generation cancellation, process cleanup, and content-type checks remain unchanged.
- Failed HTTP responses now include generation, status, response size, and content type in bounded diagnostics.

## Regression coverage

`test_games_lantern_transport.py` now covers:

- canonical and slugged effective URLs;
- cross-host and query-bearing redirect rejection;
- Windows CRLF and Wine LF status-file parsing;
- redirect count and protocol bounds in both adapters;
- final effective-URL reporting;
- HTTP failure generation/status/size diagnostics;
- all prior timeout, response-size, content-type, cancellation, and stale-generation behavior.

The complete behavior suite remains green after the change.
