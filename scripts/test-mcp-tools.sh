#!/usr/bin/env bash
#
# test-mcp-tools.sh — Smoke-test suite for the local-dev-tools MCP server
#
# Usage:  bash scripts/test-mcp-tools.sh
#
# What it does:
#   1. Starts the MCP server (bun local-dev-tools.js) as a child process
#   2. Sends JSON-RPC requests over stdin to initialize and list tools
#   3. Invokes each tool with a version/smoke command
#   4. Prints a summary table with PASS/FAIL status and version strings
#
# Prerequisites:
#   - bun (to run the MCP server and the test harness)
#   - All tools installed: python3.14t, uv, go, gh, git, dotnet, rodney
#
# Exit code: 0 if all tests pass, 1 if any fail
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_SCRIPT="$SCRIPT_DIR/../local-dev-tools.js"

# The test logic runs inside bun so we get reliable JSON parsing and async
# child-process communication with the MCP server over stdio.
exec bun -e "
const { spawn } = require('child_process');
const readline = require('readline');

const server = spawn('bun', [process.argv[1]], {
    stdio: ['pipe', 'pipe', 'pipe']
});

const rl = readline.createInterface({ input: server.stdout });
const responseQueue = [];
let requestId = 0;

rl.on('line', (line) => {
    try {
        const obj = JSON.parse(line);
        if (obj.id != null && responseQueue.length > 0) {
            responseQueue.shift()(obj);
        }
    } catch {}
});

function sendRequest(method, params) {
    return new Promise((resolve, reject) => {
        requestId++;
        const msg = JSON.stringify({ jsonrpc: '2.0', id: requestId, method, params });
        responseQueue.push(resolve);
        server.stdin.write(msg + '\n');
        setTimeout(() => reject(new Error('timeout')), 60000);
    });
}

function sendNotification(method, params) {
    const msg = JSON.stringify({ jsonrpc: '2.0', method, params });
    server.stdin.write(msg + '\n');
}

function extractVersion(text) {
    const m = text.match(/(\d+\.\d+[\.\d\w\-\+]*)/);
    return m ? m[1] : 'n/a';
}

const RED = '\x1b[31m', GREEN = '\x1b[32m', CYAN = '\x1b[36m';
const BOLD = '\x1b[1m', YELLOW = '\x1b[33m', RESET = '\x1b[0m';

async function main() {
    console.log();
    console.log(BOLD + CYAN + '========================================' + RESET);
    console.log(BOLD + CYAN + '  MCP Server Tool Test Suite' + RESET);
    console.log(BOLD + CYAN + '========================================' + RESET);
    console.log();

    // Step 1: Initialize
    process.stdout.write(BOLD + '[1/4] Initializing MCP connection...' + RESET);
    const initResp = await sendRequest('initialize', {
        protocolVersion: '2024-11-05',
        capabilities: {},
        clientInfo: { name: 'test-suite', version: '1.0.0' }
    });

    if (initResp.result?.serverInfo) {
        const si = initResp.result.serverInfo;
        console.log(GREEN + ' OK' + RESET + ' — Server: ' + si.name + ' v' + si.version);
    } else {
        console.log(RED + ' FAIL' + RESET + ' — Could not initialize');
        process.exit(1);
    }

    sendNotification('notifications/initialized');
    await new Promise(r => setTimeout(r, 200));

    // Step 2: List tools
    process.stdout.write(BOLD + '[2/4] Listing tools...' + RESET);
    const listResp = await sendRequest('tools/list', {});
    const tools = listResp.result?.tools ?? [];
    const names = tools.map(t => t.name).join(', ');

    if (tools.length === 9) {
        console.log(GREEN + ' OK' + RESET + ' — Found ' + tools.length + ' tools: ' + names);
    } else {
        console.log(YELLOW + ' WARN' + RESET + ' — Expected 9 tools, found ' + tools.length + ': ' + names);
    }

    // Step 3: Test each tool
    console.log(BOLD + '[3/4] Testing individual tools...' + RESET);
    console.log();

    const tests = [
        { name: 'python314t', args: { code: 'import sys; print(sys.version)' } },
        { name: 'bun',        args: { command: '--version' } },
        { name: 'uv',         args: { command: '--version' } },
        { name: 'uvx',        args: { package: 'ruff', args: ['version'] } },
        { name: 'go',         args: { command: 'version' } },
        { name: 'gh',         args: { command: 'version' } },
        { name: 'git',        args: { command: 'version' } },
        { name: 'dotnet',     args: { command: '--version' } },
        { name: 'rodney',     args: { args: ['--version'] } },
    ];

    const results = [];

    for (const test of tests) {
        process.stdout.write('  ' + test.name.padEnd(14));
        try {
            const resp = await sendRequest('tools/call', { name: test.name, arguments: test.args });
            const text = resp.result?.content?.[0]?.text ?? '';
            const isError = resp.result?.isError === true || resp.error != null;
            const version = extractVersion(text);

            if (!isError && text) {
                console.log(GREEN + 'PASS' + RESET + '  version: ' + version);
                results.push({ status: 'PASS', name: test.name, version });
            } else {
                const snippet = (text || resp.error?.message || 'unknown error').slice(0, 80);
                console.log(RED + 'FAIL' + RESET + '  ' + snippet);
                results.push({ status: 'FAIL', name: test.name, version: 'n/a' });
            }
        } catch (e) {
            console.log(RED + 'FAIL' + RESET + '  ' + e.message);
            results.push({ status: 'FAIL', name: test.name, version: 'n/a' });
        }
    }

    // Step 4: Summary
    console.log();
    console.log(BOLD + CYAN + '========================================' + RESET);
    console.log(BOLD + CYAN + '  Summary' + RESET);
    console.log(BOLD + CYAN + '========================================' + RESET);
    console.log('  ' + BOLD + 'STATUS'.padEnd(10) + 'TOOL'.padEnd(14) + 'VERSION' + RESET);
    console.log('  ' + '------'.padEnd(10) + '----'.padEnd(14) + '-------');

    for (const r of results) {
        const color = r.status === 'PASS' ? GREEN : RED;
        console.log('  ' + color + r.status.padEnd(10) + RESET + r.name.padEnd(14) + r.version);
    }

    const passCount = results.filter(r => r.status === 'PASS').length;
    const failCount = results.filter(r => r.status === 'FAIL').length;
    console.log();
    console.log('  ' + GREEN + 'Passed: ' + passCount + RESET + '  ' + RED + 'Failed: ' + failCount + RESET + '  Total: ' + results.length);
    console.log();

    server.kill();
    process.exit(failCount > 0 ? 1 : 0);
}

main().catch(e => { console.error(e); process.exit(1); });
" "$SERVER_SCRIPT"
