param(
    [string]$ApiKey = "",

    [string]$Version = "",

    [string]$Source = "https://api.nuget.org/v3/index.json"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$projectPath = Join-Path $repoRoot "src\HandyControl\HandyControl.csproj"
$outputDir = Join-Path $repoRoot "build\outputs\manual-pack"

if (-not $ApiKey) {
    $ApiKey = [Environment]::GetEnvironmentVariable("NuGetApiKey", "User")
}

if (-not $ApiKey) {
    throw "NuGetApiKey was not provided and was not found in the user environment variables."
}

if (Test-Path $outputDir) {
    Remove-Item $outputDir -Recurse -Force
}

$packArgs = @(
    "pack", $projectPath,
    "-c", "Release",
    "-o", $outputDir,
    "-p:BuildInParallel=false",
    "-m:1"
)

if ($Version) {
    $packArgs += "-p:Version=$Version"
    $packArgs += "-p:FileVersion=$Version"
    $packArgs += "-p:AssemblyVersion=$Version"
}

Write-Host "Packing Dev7ix.HandyControl..."
Write-Host "Using serialized pack to avoid XamlCombine file-lock conflicts."
& dotnet @packArgs
if ($LASTEXITCODE -ne 0) {
    throw "dotnet pack failed. See the MSBuild output above for the underlying error."
}

$packages = Get-ChildItem $outputDir -Filter "Dev7ix.HandyControl.*.nupkg" |
    Where-Object { $_.Name -notlike "*.snupkg" } |
    Sort-Object LastWriteTime -Descending

if (-not $packages) {
    throw "No NuGet package was produced in $outputDir."
}

$packagePath = $packages[0].FullName
Write-Host "Pushing $packagePath ..."

& dotnet nuget push $packagePath `
    --source $Source `
    --api-key $ApiKey `
    --skip-duplicate

if ($LASTEXITCODE -ne 0) {
    throw "dotnet nuget push failed."
}

Write-Host "Publish completed: $packagePath"
