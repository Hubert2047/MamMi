[CmdletBinding()]
# Edit these defaults for the usual production machine. Command-line parameters can override them.
param(
    [string]$RemoteHost = '100.67.213.27',
    [string]$RemoteUser = 'hp',
    [int]$SshPort = 22,
    [string]$Tag = $(if ($env:MAMMI_IMAGE_TAG) { $env:MAMMI_IMAGE_TAG } else { 'local' }),
    [string]$Prefix = $(if ($env:MAMMI_IMAGE_PREFIX) { $env:MAMMI_IMAGE_PREFIX } else { 'mammi' }),
    [string]$EnvFile = '.env',
    [ValidateSet('all', 'backend', 'frontend', 'order-web', 'backup')]
    [string[]]$Services = @('all'),
    [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$buildScript = Join-Path $PSScriptRoot 'build-production-images.ps1'
$selectedServices = if ($Services -contains 'all') { @('backend', 'frontend', 'order-web', 'backup') } else { $Services }
$images = $selectedServices | ForEach-Object { "$Prefix/$($_):$Tag" }

if (-not $SkipBuild) {
    & $buildScript -Tag $Tag -Prefix $Prefix -EnvFile $EnvFile -Services $selectedServices
    if ($LASTEXITCODE -ne 0) { throw 'Production image build failed.' }
}

foreach ($image in $images) {
    docker image inspect $image *> $null
    if ($LASTEXITCODE -ne 0) { throw "Image not found locally: $image" }
}

$remote = "$RemoteUser@$RemoteHost"
$sshArgs = @('-p', "$SshPort", $remote, 'docker', 'load')
Write-Host "Streaming $($images.Count) image(s) ($($selectedServices -join ', ')) to $remote ..."
docker save @images | ssh @sshArgs
if ($LASTEXITCODE -ne 0) { throw 'SSH image transfer or remote docker load failed.' }

Write-Host "Loaded images on $remote."
Write-Host 'Run docker compose on the production machine with its local .env file.'
