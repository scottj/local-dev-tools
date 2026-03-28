# AGENTS.md

## Project Overview

This is an MCP (Model Context Protocol) server called `local-dev-tools` that exposes local development tool integrations to Claude Code. It runs over stdio transport.

## Architecture

Single-file MCP server (`local-dev-tools.js`) run with Bun, using `@modelcontextprotocol/sdk`. All tool handlers are in a switch statement inside the `CallToolRequestSchema` handler. Commands are executed synchronously via `child_process.spawnSync` with `shell: true` and a 10MB output buffer.

## Tools Provided

- **python314t** — Runs Python 3.14t (free-threaded) via temp file execution
- **rodney** — Runs `uvx rodney` for web browser automation
- **bun** — Runs Bun JS/TS runtime commands
- **uv** — Runs uv Python package manager commands
- **uvx** — Runs Python CLI tools from PyPI without permanent installation
- **go** — Runs Go toolchain commands (build, test, run, mod, etc.)
- **gh** — Runs GitHub CLI commands (pr, issue, repo, api, etc.)
- **git** — Runs git version control commands
- **dotnet** — Runs .NET CLI commands (build, test, run, publish, etc.)

## Testing

Test scripts in `scripts/` verify each tool is functional and report version numbers:

- **`scripts/test-mcp-tools.ps1`** — PowerShell (Windows). Run: `powershell -File scripts\test-mcp-tools.ps1`
- **`scripts/test-mcp-tools.sh`** — Bash (Linux). Run: `bash scripts/test-mcp-tools.sh`

Both scripts start the MCP server as a child process, send JSON-RPC requests over stdio (initialize → list tools → invoke each tool), and print a color-coded pass/fail summary with version numbers. Exit code is 0 if all tools pass, 1 if any fail.

## Development

- Runtime: Bun (CommonJS `require` style)
- No build step — run directly with `bun local-dev-tools.js`
- Dependencies: `@modelcontextprotocol/sdk`

## Conventions

- Tools return `{ content: [{ type: "text", text }] }` with optional `isError: true`
- The `executeCommand` helper wraps all shell execution and returns `{ success, output, error }`
- Inline script execution for python314t and bun uses temp files (written, executed, then cleaned up)
