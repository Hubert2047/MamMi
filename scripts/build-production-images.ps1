[CmdletBinding()]
param(
    [string]$Tag = $(if ($env:MAMMI_IMAGE_TAG) { $env:MAMMI_IMAGE_TAG } else { 'local' }),
    [string]$Prefix = $(if ($env:MAMMI_IMAGE_PREFIX) { $env:MAMMI_IMAGE_PREFIX } else { 'mammi' }),
    [string]$EnvFile = '.env'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$envPath = Join-Path $projectRoot $EnvFile

function Get-DotEnvValue([string]$Name) {
    $processValue = [Environment]::GetEnvironmentVariable($Name)
    if ($processValue) { return $processValue }
    if (-not (Test-Path -LiteralPath $envPath)) { return $null }

    foreach ($line in Get-Content -LiteralPath $envPath) {
        if ($line -match "^$([regex]::Escape($Name))=(.*)$") { return $Matches[1].Trim('"') }
    }
    return $null
}

function Require-DotEnvValue([string]$Name) {
    $value = Get-DotEnvValue $Name
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Set $Name in $EnvFile or the current environment before building." }
    return $value
}

$privateHost = Require-DotEnvValue 'MAMMI_PRIVATE_HOST'
$frontendApiUrl = "http://${privateHost}:8080"
$orderWebUrl = Require-DotEnvValue 'NEXT_PUBLIC_ORDER_WEB_URL'
$turnstileSiteKey = Require-DotEnvValue 'NEXT_PUBLIC_TURNSTILE_SITE_KEY'

Push-Location $projectRoot
try {
    docker build --tag "$Prefix/backend:$Tag" ./be
    docker build --build-arg "NEXT_PUBLIC_API_BASE_URL=$frontendApiUrl" --build-arg "NEXT_PUBLIC_ORDER_WEB_URL=$orderWebUrl" --tag "$Prefix/frontend:$Tag" ./fe
    docker build --build-arg "NEXT_PUBLIC_TURNSTILE_SITE_KEY=$turnstileSiteKey" --tag "$Prefix/order-web:$Tag" ./order-web
    docker build --tag "$Prefix/backup:$Tag" ./backup
}
finally {
    Pop-Location
}

Write-Host "Built production images with tag '$Tag' and prefix '$Prefix'."
