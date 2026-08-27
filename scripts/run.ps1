#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Set-Location (Split-Path -Parent $PSScriptRoot)

if (-not (Test-Path -Path ".env")) {
    Write-Error "Falta .env. Copia .env.example a .env y rellena las claves."
    exit 1
}

flutter run --dart-define-from-file=.env @args
