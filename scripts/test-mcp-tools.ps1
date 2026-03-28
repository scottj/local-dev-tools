<#
.SYNOPSIS
    Smoke-test suite for the local-dev-tools MCP server.

.DESCRIPTION
    Starts the MCP server (bun local-dev-tools.js) as a child process,
    sends JSON-RPC requests over stdin to initialize and invoke each tool,
    then prints a summary table with PASS/FAIL status and version strings.

.EXAMPLE
    powershell -File scripts\test-mcp-tools.ps1

.NOTES
    Prerequisites: bun, python3.14t, uv, go, gh, git, dotnet, rodney
    Exit code: 0 if all tests pass, 1 if any fail
#>

$ErrorActionPreference = "Stop"
$ServerScript = Join-Path $PSScriptRoot "..\local-dev-tools.js"
$RequestId = 0
$Results = @()

# --- Start MCP server process ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  MCP Server Tool Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "bun"
$psi.Arguments = "`"$ServerScript`""
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.CreateNoWindow = $true

$proc = [System.Diagnostics.Process]::Start($psi)

function Send-JsonRpc {
    param(
        [string]$Json,
        [switch]$NoResponse
    )
    $proc.StandardInput.WriteLine($Json)
    $proc.StandardInput.Flush()

    if ($NoResponse) { return $null }

    # Read one line with timeout
    $task = $proc.StandardOutput.ReadLineAsync()
    if ($task.Wait(60000)) {
        return $task.Result
    } else {
        return '{"error":"timeout"}'
    }
}

function Call-Tool {
    param(
        [string]$ToolName,
        [string]$Arguments
    )
    $script:RequestId++
    $request = "{`"jsonrpc`":`"2.0`",`"id`":$($script:RequestId),`"method`":`"tools/call`",`"params`":{`"name`":`"$ToolName`",`"arguments`":$Arguments}}"
    return Send-JsonRpc -Json $request
}

function Extract-VersionFromText {
    param([string]$Text)
    if ($Text -match '(\d+\.\d+[\.\d+\w\-\+]*)') {
        return $Matches[1]
    }
    return "n/a"
}

function Parse-Response {
    param([string]$Response)
    try {
        $obj = $Response | ConvertFrom-Json
        $text = $obj.result.content[0].text
        $isError = ($obj.result.isError -eq $true) -or ($null -ne $obj.error)
        return @{ Text = $text; IsError = $isError }
    } catch {
        return @{ Text = "PARSE_ERROR"; IsError = $true }
    }
}

try {
    # --- Step 1: Initialize ---
    Write-Host "[1/4] Initializing MCP connection..." -NoNewline
    $script:RequestId++
    $initReq = "{`"jsonrpc`":`"2.0`",`"id`":$($script:RequestId),`"method`":`"initialize`",`"params`":{`"protocolVersion`":`"2024-11-05`",`"capabilities`":{},`"clientInfo`":{`"name`":`"test-suite`",`"version`":`"1.0.0`"}}}"
    $initResp = Send-JsonRpc -Json $initReq
    $initObj = $initResp | ConvertFrom-Json

    if ($initObj.result.serverInfo) {
        $serverName = $initObj.result.serverInfo.name
        $serverVer = $initObj.result.serverInfo.version
        Write-Host " OK" -ForegroundColor Green -NoNewline
        Write-Host " - Server: $serverName v$serverVer"
    } else {
        Write-Host " FAIL" -ForegroundColor Red
        Write-Host "Could not initialize MCP server"
        exit 1
    }

    # Send initialized notification
    Send-JsonRpc -Json '{"jsonrpc":"2.0","method":"notifications/initialized"}' -NoResponse
    Start-Sleep -Milliseconds 200

    # --- Step 2: List tools ---
    Write-Host "[2/4] Listing tools..." -NoNewline
    $script:RequestId++
    $listReq = "{`"jsonrpc`":`"2.0`",`"id`":$($script:RequestId),`"method`":`"tools/list`",`"params`":{}}"
    $listResp = Send-JsonRpc -Json $listReq
    $listObj = $listResp | ConvertFrom-Json
    $toolCount = $listObj.result.tools.Count
    $toolNames = ($listObj.result.tools | ForEach-Object { $_.name }) -join ", "

    if ($toolCount -eq 9) {
        Write-Host " OK" -ForegroundColor Green -NoNewline
        Write-Host " - Found $toolCount tools: $toolNames"
    } else {
        Write-Host " WARN" -ForegroundColor Yellow -NoNewline
        Write-Host " - Expected 9 tools, found ${toolCount}: $toolNames"
    }

    # --- Step 3: Test each tool ---
    Write-Host "[3/4] Testing individual tools..."
    Write-Host ""

    $tests = @(
        @{ Name = "python314t"; Args = '{"code":"import sys; print(sys.version)"}' },
        @{ Name = "bun";        Args = '{"command":"--version"}' },
        @{ Name = "uv";         Args = '{"command":"--version"}' },
        @{ Name = "uvx";        Args = '{"package":"ruff","args":["version"]}' },
        @{ Name = "go";         Args = '{"command":"version"}' },
        @{ Name = "gh";         Args = '{"command":"version"}' },
        @{ Name = "git";        Args = '{"command":"version"}' },
        @{ Name = "dotnet";     Args = '{"command":"--version"}' },
        @{ Name = "rodney";     Args = '{"args":["--version"]}' }
    )

    $passCount = 0
    $failCount = 0

    foreach ($test in $tests) {
        $name = $test.Name
        Write-Host ("  {0,-14}" -f $name) -NoNewline

        $response = Call-Tool -ToolName $name -Arguments $test.Args
        $parsed = Parse-Response -Response $response
        $version = Extract-VersionFromText -Text $parsed.Text

        if (-not $parsed.IsError -and $parsed.Text -ne "NO_OUTPUT") {
            Write-Host "PASS" -ForegroundColor Green -NoNewline
            Write-Host "  version: $version"
            $Results += @{ Status = "PASS"; Name = $name; Version = $version }
            $passCount++
        } else {
            $snippet = if ($parsed.Text.Length -gt 80) { $parsed.Text.Substring(0, 80) } else { $parsed.Text }
            Write-Host "FAIL" -ForegroundColor Red -NoNewline
            Write-Host "  $snippet"
            $Results += @{ Status = "FAIL"; Name = $name; Version = "n/a" }
            $failCount++
        }
    }

    # --- Step 4: Summary ---
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ("  {0,-10} {1,-14} {2}" -f "STATUS", "TOOL", "VERSION")
    Write-Host ("  {0,-10} {1,-14} {2}" -f "------", "----", "-------")

    foreach ($r in $Results) {
        $color = if ($r.Status -eq "PASS") { "Green" } else { "Red" }
        Write-Host ("  ") -NoNewline
        Write-Host ("{0,-10}" -f $r.Status) -ForegroundColor $color -NoNewline
        Write-Host ("{0,-14} {1}" -f $r.Name, $r.Version)
    }

    Write-Host ""
    Write-Host "  Passed: $passCount" -ForegroundColor Green -NoNewline
    Write-Host "  Failed: $failCount" -ForegroundColor Red -NoNewline
    Write-Host "  Total: $($passCount + $failCount)"
    Write-Host ""

    if ($failCount -gt 0) { exit 1 }

} finally {
    # Clean up server process
    try {
        $proc.StandardInput.Close()
        if (-not $proc.HasExited) {
            $proc.Kill()
        }
        $proc.Dispose()
    } catch {}
}
