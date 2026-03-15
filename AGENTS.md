# AGENTS.md

## Project Overview

This is an MCP (Model Context Protocol) server called `local-dev-tools` that exposes local development tool integrations to Claude Code. It runs over stdio transport.

## Architecture

Single-file Node.js MCP server (`local-dev-tools.js`) using `@modelcontextprotocol/sdk`. All tool handlers are in a switch statement inside the `CallToolRequestSchema` handler. Commands are executed synchronously via `child_process.execSync` with a 10MB output buffer.

## Tools Provided

- **python314t** — Runs Python 3.14t (free-threaded) via `python3.14t.exe -c`
- **rodney** — Runs `uvx rodney` for web browser automation
- **bun** — Runs Bun JS/TS runtime commands
- **uv** — Runs uv Python package manager commands
- **uvx** — Runs Python CLI tools from PyPI without permanent installation
- **go** — Runs Go toolchain commands (build, test, run, mod, etc.)
- **gh** — Runs GitHub CLI commands (pr, issue, repo, api, etc.)
- **git** — Runs git version control commands
- **dotnet** — Runs .NET CLI commands (build, test, run, publish, etc.)

## Development

- Runtime: Node.js (CommonJS `require` style)
- No build step — run directly with `node local-dev-tools.js`
- Dependencies: `@modelcontextprotocol/sdk`

## Conventions

- Tools return `{ content: [{ type: "text", text }] }` with optional `isError: true`
- The `executeCommand` helper wraps all shell execution and returns `{ success, output, error }`
- Inline script execution for bun is intentionally unsupported; write to a file first
