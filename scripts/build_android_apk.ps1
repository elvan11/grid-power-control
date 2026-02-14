param(
  [ValidateSet("debug", "profile", "release")]
  [string]$BuildMode = "debug",
  [string]$SupabaseUrl = $env:SUPABASE_URL,
  [string]$SupabaseAnonKey = $env:SUPABASE_ANON_KEY,
  [switch]$SplitPerAbi,
  [switch]$Clean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($SupabaseUrl)) {
  throw "Missing Supabase URL. Pass -SupabaseUrl or set SUPABASE_URL env var."
}

if ([string]::IsNullOrWhiteSpace($SupabaseAnonKey)) {
  throw "Missing Supabase anon key. Pass -SupabaseAnonKey or set SUPABASE_ANON_KEY env var."
}

$repoRoot = Resolve-Path "$PSScriptRoot\.."
$appDir = Join-Path $repoRoot "app"

function Invoke-Step {
  param(
    [Parameter(Mandatory = $true)]
    [scriptblock]$Script,
    [Parameter(Mandatory = $true)]
    [string]$ErrorMessage
  )

  & $Script
  if ($LASTEXITCODE -ne 0) {
    throw "$ErrorMessage (exit code: $LASTEXITCODE)"
  }
}

Push-Location $appDir
try {
  if ($Clean) {
    Write-Host "Running flutter clean..."
    Invoke-Step -Script { flutter clean | Out-Host } -ErrorMessage "flutter clean failed"
  }

  Write-Host "Running flutter pub get..."
  Invoke-Step -Script { flutter pub get | Out-Host } -ErrorMessage "flutter pub get failed"

  $args = @(
    "build", "apk", "--$BuildMode",
    "--dart-define=SUPABASE_URL=$SupabaseUrl",
    "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
  )

  if ($SplitPerAbi) {
    $args += "--split-per-abi"
  }

  Write-Host ("Running flutter {0}" -f ($args -join " "))
  & flutter @args | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "flutter build apk failed (exit code: $LASTEXITCODE)"
  }
} finally {
  Pop-Location
}

Write-Host ""
Write-Host "APK build complete."
if ($SplitPerAbi) {
  Write-Host "Output directory: app/build/app/outputs/flutter-apk/"
  Write-Host "Expected files: app-*-debug.apk / app-*-profile.apk / app-*-release.apk (per ABI)."
} else {
  Write-Host ("Output file: app/build/app/outputs/flutter-apk/app-$BuildMode.apk")
}
