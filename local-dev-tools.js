const { Server } = require("@modelcontextprotocol/sdk/server/index.js");
const { StdioServerTransport } = require("@modelcontextprotocol/sdk/server/stdio.js");
const { CallToolRequestSchema, ListToolsRequestSchema } = require("@modelcontextprotocol/sdk/types.js");
const { execSync, spawn } = require("child_process");
const path = require("path");

const server = new Server({
  name: "local-dev-tools",
  version: "1.0.0",
});

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
      description: "Run uvx rodney for AI-assisted development tasks. Rodney provides intelligent code analysis and generation capabilities.",
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
  ],
}));

function executeCommand(cmd, args = [], cwd = process.cwd()) {
  try {
    const fullCmd = args.length > 0 ? `${cmd} ${args.join(" ")}` : cmd;
    const result = execSync(fullCmd, {
      encoding: "utf-8",
      cwd: cwd,
      stdio: ["pipe", "pipe", "pipe"],
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer
    });
    return { success: true, output: result };
  } catch (error) {
    return {
      success: false,
      output: error.stdout || "",
      error: error.stderr || error.message,
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
        result = executeCommand(`python3.14t.exe -c "${code.replace(/"/g, '\\"')}"`, args);
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
          // For inline script code, we'd need to handle it differently
          result = {
            success: false,
            error: "For inline scripts, please write to a file first, then use bun run <file>",
          };
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