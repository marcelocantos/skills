#!/usr/bin/env bash
# Run one read-only SQL query against the mnemo daemon over its MCP endpoint
# directly, bypassing the session's MCP proxy. Fallback for the /vcheck
# checker when the in-session `mnemo_query` tool is unreachable (the proxy
# route has been observed refusing connections while the daemon itself
# answers). Prints the tool's text result; exits non-zero on transport error.
#
# Usage: mnemo-sql.sh '<sql>'
#   MNEMO_MCP_URL   endpoint (default http://127.0.0.1:19419/mcp)
#   MNEMO_TIMEOUT   per-request seconds (default 90)
#
# Dependencies: curl, jq (JSON encoding of the query string only).
set -euo pipefail

url="${MNEMO_MCP_URL:-http://127.0.0.1:19419/mcp}"
timeout_s="${MNEMO_TIMEOUT:-90}"
sql="${1:?usage: mnemo-sql.sh '<sql>'}"

hdrs=$(mktemp)
trap 'rm -f "$hdrs"' EXIT

post() {
    curl -sS -m "$timeout_s" -X POST "$url" \
        -H 'content-type: application/json' \
        -H 'accept: application/json, text/event-stream' "$@"
}

post -D "$hdrs" -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"vcheck","version":"0"}}}' >/dev/null
sid=$(grep -i '^mcp-session-id:' "$hdrs" | tr -d '\r' | awk '{print $2}')
if [[ -z "$sid" ]]; then
    echo "error: no MCP session id from $url" >&2
    exit 1
fi
post -H "mcp-session-id: $sid" -d '{"jsonrpc":"2.0","method":"notifications/initialized"}' >/dev/null

body=$(jq -cn --arg q "$sql" '{jsonrpc:"2.0",id:2,method:"tools/call",params:{name:"mnemo_query",arguments:{query:$q}}}')
post -H "mcp-session-id: $sid" -d "$body" \
    | jq -r 'if .error then ("error: " + .error.message) else ([.result.content[]? | .text] | join("\n")) end'
