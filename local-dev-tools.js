const { Server } = require("@modelcontextprotocol/sdk/server/index.js");
const { StdioServerTransport } = require("@modelcontextprotocol/sdk/server/stdio.js");
const { CallToolRequestSchema, ListToolsRequestSchema } = require("@modelcontextprotocol/sdk/types.js");
const { spawnSync } = require("child_process");
const path = require("path");
const fs = require("fs");
const os = require("os");

const server = new Server(
  {
    name: "local-dev-tools",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: "python314t",
      description: "Run Python 3.14t interpreter. Use for executing Python code.",
      inputSchema: {
        type: "object",
        properties: {
          code: {
            type: "string",
            description: "Python code to execute",
          },
          args: {
            type: "array",
            items: { type: "string" },
            description: "Command-line arguments to pass to python3.14t",
          },
        },
        required: ["code"],
      },
    },
    {
      name: "rodney",
      description: "Run uvx rodney for web browser automation. Rodney provides browser control capabilities for testing and scraping.",
      inputSchema: {
        type: "object",
        properties: {
          args: {
            type: "array",
            items: { type: "string" },
            description: "Arguments to pass to rodney (e.g., ['--help'], ['analyze', 'file.js'], etc.)",
          },
        },
        required: ["args"],
      },
    },
    {
      name: "bun",
      description: "Run Bun JavaScript runtime. Use for executing JavaScript/TypeScript or running Bun commands.",
      inputSchema: {
        type: "object",
        properties: {
          command: {
            type: "string",
            description: "Bun command (e.g., 'run', 'install', 'build', 'test')",
          },
          args: {
            type: "array",
            items: { type: "string" },
            description: "Arguments for the bun command",
          },
          scriptCode: {
            type: "string",
            description: "JavaScript/TypeScript code to run directly with 'bun run'",
          },
        },
        required: ["command"],
      },
    },
    {
      name: "uv",
      description: "Run uv Python package manager. Use for managing Python dependencies, virtual environments, and running scripts.",
      inputSchema: {
        type: "object",
        properties: {
          command: {
            type: "string",
            description: "uv command (e.g., 'pip', 'venv', 'run', 'sync', 'lock')",
          },
          args: {
            type: "array",
            items: { type: "string" },
            description: "Arguments for the uv command",
          },
        },
        required: ["command"],
      },
    },
    {
      name: "uvx",
      description: "Run uvx to execute Python CLI tools from PyPI without installing them permanently.",
      inputSchema: {
        type: "object",
        properties: {
          package: {
            type: "string",
            description: "The package/tool to run (e.g., 'black', 'ruff', 'mypy')",
          },
          args: {
            type: "array",
            items: { type: "string" },
            description: "Arguments to pass to the tool",
          },
        },
        required: ["package"],
      },
    },
    {
      name: "go",
      description: "Run Go toolchain commands. Use for building, testing, and managing Go projects.",
      inputSchema: {
        type: "object",
        properties: {
          command: {
            type: "string",
            description: "Go command (e.g., 'build', 'test', 'run', 'mod', 'vet', 'fmt')",
          },
          args: {
            type: "array",
            items: { type: "string" },
            description: "Arguments for the go command",
          },
        },
        required: ["command"],
      },
    },
    {
      name: "gh",
      description: "Run GitHub CLI commands. Use for interacting with GitHub repositories, issues, PRs, and more.",
      inputSchema: {
        type: "object",
        properties: {
          command: {
            type: "string",
            description: "gh command (e.g., 'pr', 'issue', 'repo', 'run', 'api')",
          },
          args: {
            type: "array",
            items: { type: "string" },
            description: "Arguments for the gh command",
          },
        },
        required: ["command"],
      },
    },
    {
      name: "git",
      description: "Run git version control commands. Use for repository management, branching, committing, and history.",
      inputSchema: {
        type: "object",
        properties: {
          command: {
            type: "string",
            description: "git command (e.g., 'status', 'log', 'diff', 'branch', 'checkout', 'commit')",
          },
          args: {
            type: "array",
            items: { type: "string" },
            description: "Arguments for the git command",
          },
        },
        required: ["command"],
      },
    },
    {
      name: "dotnet",
      description: "Run .NET CLI commands. Use for building, testing, and managing .NET projects.",
      inputSchema: {
        type: "object",
        properties: {
          command: {
            type: "string",
            description: "dotnet command (e.g., 'build', 'test', 'run', 'new', 'add', 'publish')",
          },
          args: {
            type: "array",
            items: { type: "string" },
            description: "Arguments for the dotnet command",
          },
        },
        required: ["command"],
      },
    },
  ],
}));

function executeCommand(cmd, args = [], cwd = process.cwd()) {
  const result = spawnSync(cmd, args, {
    encoding: "utf-8",
    cwd: cwd,
    stdio: ["pipe", "pipe", "pipe"],
    maxBuffer: 10 * 1024 * 1024, // 10MB buffer
    shell: true,
  });

  const stdout = result.stdout || "";
  const stderr = result.stderr || "";
  const output = [stdout, stderr].filter(Boolean).join("\n");

  if (result.status === 0) {
    return { success: true, output };
  } else {
    return {
      success: false,
      output,
      error: result.error ? result.error.message : "",
    };
  }
}

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  try {
    let result;

    switch (request.params.name) {
      case "python314t": {
        const code = request.params.arguments.code;
        const args = request.params.arguments.args || [];
        const tmpFile = path.join(os.tmpdir(), `claude-python-${Date.now()}.py`);
        fs.writeFileSync(tmpFile, code);
        try {
          result = executeCommand("python3.14t.exe", [tmpFile, ...args]);
        } finally {
          try { fs.unlinkSync(tmpFile); } catch {}
        }
        break;
      }

      case "rodney": {
        const args = request.params.arguments.args || [];
        result = executeCommand("uvx", ["rodney", ...args]);
        break;
      }

      case "bun": {
        const command = request.params.arguments.command;
        const args = request.params.arguments.args || [];
        const scriptCode = request.params.arguments.scriptCode;

        if (scriptCode && command === "run") {
          const tmpFile = path.join(os.tmpdir(), `claude-bun-${Date.now()}.ts`);
          fs.writeFileSync(tmpFile, scriptCode);
          try {
            result = executeCommand("bun", ["run", tmpFile, ...args]);
          } finally {
            try { fs.unlinkSync(tmpFile); } catch {}
          }
        } else {
          result = executeCommand("bun", [command, ...args]);
        }
        break;
      }

      case "uv": {
        const command = request.params.arguments.command;
        const args = request.params.arguments.args || [];
        result = executeCommand("uv", [command, ...args]);
        break;
      }

      case "uvx": {
        const pkg = request.params.arguments.package;
        const args = request.params.arguments.args || [];
        result = executeCommand("uvx", [pkg, ...args]);
        break;
      }

      case "go": {
        const command = request.params.arguments.command;
        const args = request.params.arguments.args || [];
        result = executeCommand("go", [command, ...args]);
        break;
      }

      case "gh": {
        const command = request.params.arguments.command;
        const args = request.params.arguments.args || [];
        result = executeCommand("gh", [command, ...args]);
        break;
      }

      case "git": {
        const command = request.params.arguments.command;
        const args = request.params.arguments.args || [];
        result = executeCommand("git", [command, ...args]);
        break;
      }

      case "dotnet": {
        const command = request.params.arguments.command;
        const args = request.params.arguments.args || [];
        result = executeCommand("dotnet", [command, ...args]);
        break;
      }

      default:
        return {
          content: [
            {
              type: "text",
              text: `Unknown tool: ${request.params.name}`,
            },
          ],
          isError: true,
        };
    }

    if (result.success) {
      return {
        content: [
          {
            type: "text",
            text: result.output || "(Command executed successfully with no output)",
          },
        ],
      };
    } else {
      return {
        content: [
          {
            type: "text",
            text: `Error executing ${request.params.name}:\n${result.error || result.output}`,
          },
        ],
        isError: true,
      };
    }
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Unexpected error: ${error.message}`,
        },
      ],
      isError: true,
    };
  }
});

const transport = new StdioServerTransport();
server.connect(transport);
