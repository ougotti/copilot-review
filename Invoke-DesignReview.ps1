#
# PowerShell wrapper for design_review.py running on .venv Python.
# Keep this file ASCII-only so it runs correctly in Windows PowerShell 5.x.
#
param(
    [string]$Type = "",

    [string]$Name = "",

    [string]$Doc = "all",

    [string]$Model = "",

    [switch]$Force
)

$ErrorActionPreference = "Stop"

$pythonPath = Join-Path $PSScriptRoot ".venv\Scripts\python.exe"
$scriptPath = Join-Path $PSScriptRoot "design_review.py"

if (-not (Test-Path $pythonPath)) {
    Write-Error "Python executable not found in .venv: $pythonPath`nCreate .venv and install requirements.txt first."
    exit 1
}

if (-not (Test-Path $scriptPath)) {
    Write-Error "Review runner script not found: $scriptPath"
    exit 1
}

$arguments = @($scriptPath)

if ($Type -ne "") {
    $arguments += @("--type", $Type)
}

if ($Name -ne "") {
    $arguments += @("--name", $Name)
}

$arguments += @("--doc", $Doc)

if ($Model -ne "") {
    $arguments += @("--model", $Model)
}

if ($Force) {
    $arguments += "--force"
}

& $pythonPath @arguments
exit $LASTEXITCODE