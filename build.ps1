<#
.SYNOPSIS
  PowerShell build script for OpenplanetNext plugins

  This script was generated using chatGPT... please dont use it in your production stuff.

.USAGE
  .\build.ps1 [dev|release|prerelease|unittest]
  Defaults to `dev` mode if not specified.
#>

param(
    [string]$BuildMode = "dev"
)

# Validate build mode
$validModes = @("dev","release","prerelease","unittest")
if (-not ($validModes -contains $BuildMode)) {
    Write-Host "⚠ Error: build mode '$BuildMode' is not valid. Options: dev, release, prerelease, unittest." -ForegroundColor Red
    exit 1
}
Write-Host "🚩 Build mode: $BuildMode" -ForegroundColor Yellow

# Mapping for pretty suffixes and defines
$suffixMap = @{ dev = '(Dev)'; prerelease = '(Prerelease)'; unittest = '(UnitTest)' }
$definesMap = @{ dev = 'DEV'; prerelease = 'RELEASE'; unittest = 'UNIT_TEST' }

# Plugin sources (folders to package)
$pluginSources = @('src')

# Determine plugins directory (env override or user profile)
$pluginsDir = if ($env:PLUGINS_DIR) { $env:PLUGINS_DIR } else { Join-Path $env:USERPROFILE 'OpenplanetNext\Plugins' }

# Helper: build ZIP and convert to .op (with versioned .op name)
function Build-Plugin {
    param(
        [string]$SourceDir,
        [string]$NameBase,
        [string]$Version
    )
    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $zipName = "$NameBase-$timestamp.zip"
    $opName  = "$NameBase-$Version.op"

    7z a $zipName "./$SourceDir/*" './LICENSE' './README.md' | Out-Null
    Copy-Item -Path $zipName -Destination $opName -Force
    Write-Host "`n✅ Built: $zipName -> $opName`n" -ForegroundColor Green
    return @{ Zip = $zipName; Op = $opName }
}

foreach ($pluginSrc in $pluginSources) {
    # Read base info
    $infoPath = Join-Path -Path . -ChildPath 'info.toml'
    $infoLines = Get-Content $infoPath -ErrorAction Stop
    $baseNameLine = $infoLines | Where-Object { $_ -match '^name' } | Select-Object -First 1
    $baseVersionLine = $infoLines | Where-Object { $_ -match '^version' } | Select-Object -First 1
    $baseName = ($baseNameLine.Split('=',2)[1]).Trim(' "')
    $pluginVersion = ($baseVersionLine.Split('=',2)[1]).Trim(' "')

    # Determine pretty name and defines marker
    $prettySuffix = $suffixMap[$BuildMode]
    $pluginPretty = if ($prettySuffix) { "$baseName $prettySuffix" } else { $baseName }
    $marker = $definesMap[$BuildMode]

    Write-Host "`n🔨 Packaging: $pluginPretty (mode: $BuildMode)" -ForegroundColor Cyan

    # Prep info.toml in source
    Copy-Item -Path $infoPath -Destination "./$pluginSrc/info.toml" -Force
    (Get-Content "./$pluginSrc/info.toml") | ForEach-Object {
        if ($_ -match '^(name\s*=)') {
            'name = "' + $pluginPretty + '"'
        } elseif ($_ -match '^#__DEFINES__') {
            'defines = ["' + $marker + '"]'
        } else {
            $_
        }
    } | Set-Content "./$pluginSrc/info.toml"

    # Slugify for output names
    $slug = $pluginPretty -replace '[\(\),;''"`]', '' -replace '\s+', '-'
    $slug = $slug.ToLower()

    # Build with versioned .op filename
    $result = Build-Plugin -SourceDir $pluginSrc -NameBase $slug -Version $pluginVersion

    # Deploy .op
    $destPath = Join-Path $pluginsDir $result.Op
    Copy-Item -Path $result.Op -Destination $destPath -Force
    if ($?) {
        Write-Host "✅ Deployed: $destPath" -ForegroundColor Green
    } else {
        Write-Host "⚠ Failed to deploy to $destPath" -ForegroundColor Red
    }

    # Cleanup temp info.toml
    Remove-Item "./$pluginSrc/info.toml" -Force
}

Write-Host "🏁 All done!" -ForegroundColor Green
