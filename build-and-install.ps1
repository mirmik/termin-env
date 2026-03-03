#!/usr/bin/env pwsh
# Build and install all termin libraries in dependency order:
#   termin-base -> termin-scene -> termin-graphics -> termin-gui -> termin
#
# Usage:
#   .\build-and-install.ps1              # Release build
#   .\build-and-install.ps1 --debug      # Debug build
#   .\build-and-install.ps1 --clean      # Clean before build
#   .\build-and-install.ps1 --only=base  # Build only termin-base
#   .\build-and-install.ps1 --only=scene # Build only termin-scene
#   .\build-and-install.ps1 --only=gfx   # Build only termin-graphics
#   .\build-and-install.ps1 --only=app   # Build only termin
#   .\build-and-install.ps1 --from=scene # Start from termin-scene (skip base)
#   .\build-and-install.ps1 --from=gfx   # Start from termin-graphics (skip base + scene)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BuildType = "Release"
$Clean = $false
$Only = ""
$From = ""
$LocalAppDataDir = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path $HOME "AppData\Local" }
$SdkDir = Join-Path $LocalAppDataDir "termin-sdk"

function Show-Help {
    Write-Host "Usage: .\build-and-install.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  --debug, -d       Debug build"
    Write-Host "  --clean, -c       Clean build directories first"
    Write-Host "  --only=base       Build only termin-base"
    Write-Host "  --only=scene      Build only termin-scene"
    Write-Host "  --only=gfx        Build only termin-graphics"
    Write-Host "  --only=gui        Build only termin-gui + termin-nodegraph"
    Write-Host "  --only=app        Build only termin"
    Write-Host "  --from=base       Build from termin-base onwards (all)"
    Write-Host "  --from=scene      Build from termin-scene onwards (skip base)"
    Write-Host "  --from=gfx        Build from termin-graphics onwards (skip base and scene)"
    Write-Host "  --from=gui        Build from termin-gui onwards (skip base, scene and gfx)"
    Write-Host "  --from=app        Build only termin (skip base, scene, gfx, gui)"
    Write-Host "  --help, -h        Show this help"
}

foreach ($arg in $args) {
    switch ($arg) {
        "--debug" { $BuildType = "Debug" }
        "-d" { $BuildType = "Debug" }
        "--clean" { $Clean = $true }
        "-c" { $Clean = $true }
        "--only=base" { $Only = "base" }
        "--only=scene" { $Only = "scene" }
        "--only=gfx" { $Only = "gfx" }
        "--only=gui" { $Only = "gui" }
        "--only=app" { $Only = "app" }
        "--from=base" { $From = "base" }
        "--from=scene" { $From = "scene" }
        "--from=gfx" { $From = "gfx" }
        "--from=gui" { $From = "gui" }
        "--from=app" { $From = "app" }
        "--help" { Show-Help; exit 0 }
        "-h" { Show-Help; exit 0 }
        default {
            Write-Error "Unknown option: $arg"
            exit 1
        }
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code $LASTEXITCODE"
    }
}

function Should-Build {
    param([string]$Name)

    if ($Only) {
        return ($Only -eq $Name)
    }

    if ($From) {
        switch ($From) {
            "base" { return $true }
            "scene" { return ($Name -ne "base") }
            "gfx" { return ($Name -eq "gfx" -or $Name -eq "gui" -or $Name -eq "app") }
            "gui" { return ($Name -eq "gui" -or $Name -eq "app") }
            "app" { return ($Name -eq "app") }
        }
    }

    return $true
}

function Build-CMakeLib {
    param(
        [string]$Name,
        [string]$Dir,
        [switch]$NoBuildIsolation,
        [string[]]$ExtraPrefixPaths = @()
    )

    Write-Host ""
    Write-Host "========================================"
    Write-Host "  Building $Name ($BuildType)"
    Write-Host "========================================"
    Write-Host ""

    Push-Location $Dir
    try {
        $buildDir = Join-Path "build" $BuildType
        $installDir = $SdkDir
        $prefixPaths = @($SdkDir) + $ExtraPrefixPaths
        $prefixPathArg = ($prefixPaths | Where-Object { $_ } | Select-Object -Unique) -join ";"
        $terminBaseDir = Join-Path $SdkDir "lib\cmake\termin_base"
        $terminGraphicsDir = Join-Path $SdkDir "lib\cmake\termin_graphics"

        if ($Clean) {
            Write-Host "Cleaning $buildDir..."
            if (Test-Path $buildDir) {
                Remove-Item -Recurse -Force $buildDir
            }
        }

        if (-not (Test-Path $buildDir)) {
            New-Item -ItemType Directory -Path $buildDir | Out-Null
        }
        if (-not (Test-Path $installDir)) {
            New-Item -ItemType Directory -Path $installDir | Out-Null
        }

        $cmakeArgs = @(
            "-S", ".",
            "-B", $buildDir,
            "-DCMAKE_BUILD_TYPE=$BuildType",
            "-DCMAKE_INSTALL_PREFIX=$installDir",
            "-DCMAKE_PREFIX_PATH=$prefixPathArg"
        )
        if ($Name -eq "termin-graphics" -and (Test-Path $terminBaseDir)) {
            $cmakeArgs += "-Dtermin_base_DIR=$terminBaseDir"
        }
        if ($Name -eq "termin" -and (Test-Path $terminBaseDir)) {
            $cmakeArgs += "-Dtermin_base_DIR=$terminBaseDir"
        }
        if ($Name -eq "termin" -and (Test-Path $terminGraphicsDir)) {
            $cmakeArgs += "-Dtermin_graphics_DIR=$terminGraphicsDir"
        }

        & cmake @cmakeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE"
        }
        Invoke-Checked { cmake --build $buildDir --config $BuildType --parallel }
        Invoke-Checked { cmake --install $buildDir --config $BuildType }

        if ($Name -eq "termin-scene") {
            Write-Host "Skipping Python package install for $Name"
        } else {
            Write-Host "Installing $Name Python package..."
            if ($NoBuildIsolation) {
                Invoke-Checked { python -m pip install --no-build-isolation . }
            }
            else {
                Invoke-Checked { python -m pip install . }
            }
        }

        Write-Host "$Name installed to $installDir"
    }
    finally {
        Pop-Location
    }
}

function Build-Termin {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  Building termin ($BuildType)"
    Write-Host "========================================"
    Write-Host ""

    Push-Location (Join-Path $ScriptDir "termin")
    try {
        $buildArgs = @()
        if ($BuildType -eq "Debug") {
            $buildArgs += "-Debug"
        }
        if ($Clean) {
            $buildArgs += "-Clean"
        }

        $oldPrefix = $env:CMAKE_PREFIX_PATH
        try {
            if ($oldPrefix) {
                $env:CMAKE_PREFIX_PATH = "$SdkDir;$oldPrefix"
            }
            else {
                $env:CMAKE_PREFIX_PATH = $SdkDir
            }
            Invoke-Checked { .\build.ps1 @buildArgs }
        }
        finally {
            if ($null -eq $oldPrefix) {
                Remove-Item Env:CMAKE_PREFIX_PATH -ErrorAction SilentlyContinue
            }
            else {
                $env:CMAKE_PREFIX_PATH = $oldPrefix
            }
        }
    }
    finally {
        Pop-Location
    }
}

# Build chain
if (Should-Build "base") {
    Build-CMakeLib -Name "termin-base" -Dir (Join-Path $ScriptDir "termin-base")
}

if (Should-Build "scene") {
    Build-CMakeLib -Name "termin-scene" -Dir (Join-Path $ScriptDir "termin-scene")
}

if (Should-Build "gfx") {
    Build-CMakeLib -Name "termin-graphics" -Dir (Join-Path $ScriptDir "termin-graphics") -NoBuildIsolation -ExtraPrefixPaths @($SdkDir)
}

if (Should-Build "gui") {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  Installing termin-gui (pip)"
    Write-Host "========================================"
    Write-Host ""
    Invoke-Checked { python -m pip install (Join-Path $ScriptDir "termin-gui") }

    Write-Host ""
    Write-Host "========================================"
    Write-Host "  Installing termin-nodegraph (pip)"
    Write-Host "========================================"
    Write-Host ""
    Invoke-Checked { python -m pip install (Join-Path $ScriptDir "termin-nodegraph") }
}

if (Should-Build "app") {
    Build-Termin
}

Write-Host ""
Write-Host "========================================"
Write-Host "  All done!"
Write-Host "========================================"
