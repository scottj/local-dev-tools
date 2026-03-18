# local-dev-tools

An MCP (Model Context Protocol) server that gives Claude Code access to local development tools. It runs over stdio transport using Bun.

## Tools

| Tool | Description |
|------|-------------|
| **python314t** | Run Python 3.14t (free-threaded) code |
| **bun** | Run Bun JS/TS runtime commands, including inline scripts |
| **uv** | Manage Python dependencies and virtual environments |
| **uvx** | Run Python CLI tools from PyPI without installing them |
| **go** | Run Go toolchain commands (build, test, run, mod, etc.) |
| **gh** | Run GitHub CLI commands (pr, issue, repo, api, etc.) |
| **git** | Run git version control commands |
| **dotnet** | Run .NET CLI commands (build, test, run, publish, etc.) |
| **rodney** | Browser automation via uvx rodney |

## Prerequisites

The following must be available on your PATH:

- [Bun](https://bun.sh) (used to run the MCP server itself)
- [python3.14t](https://docs.python.org/3.14/whatsnew/3.14.html) — free-threaded Python build
- [uv](https://docs.astral.sh/uv/) — for `uv`, `uvx`, and `rodney` tools
- [Go](https://go.dev)
- [GitHub CLI](https://cli.github.com)
- [Git](https://git-scm.com)
- [.NET SDK](https://dotnet.microsoft.com)

## Setup

1. Install the MCP SDK dependency:

   ```sh
   bun install @modelcontextprotocol/sdk
   ```

2. Add the server to your Claude Code MCP configuration (`~/.claude.json` under `mcpServers`):

   ```json
   {
     "mcpServers": {
       "local-dev-tools": {
         "type": "stdio",
         "command": "bun",
         "args": ["C:\\path\\to\\local-dev-tools.js"],
         "env": {}
       }
     }
   }
   ```

   Or on macOS/Linux:

   ```json
   {
     "mcpServers": {
       "local-dev-tools": {
         "type": "stdio",
         "command": "bun",
         "args": ["/path/to/local-dev-tools.js"],
         "env": {}
       }
     }
   }
   ```

3. Restart Claude Code or run `/mcp` to reconnect.

## Usage

Once connected, Claude Code can invoke any of the tools directly. Examples:

- **Run Python code:** `python314t` with `code: "print('hello')"`
- **Run a Bun script inline:** `bun` with `command: "run"` and `scriptCode: "console.log('hi')"`
- **Install npm packages:** `bun` with `command: "install"` and `args: ["lodash"]`
- **Lint Python files:** `uvx` with `package: "ruff"` and `args: ["check", "."]`
- **Check git status:** `git` with `command: "status"`
