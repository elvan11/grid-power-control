param(
  [string]$BaseUrl = "http://127.0.0.1:7357",
  [string]$Routes = "/#/installations,/#/today,/#/schedules,/#/settings,/#/settings/sharing"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$playwrightCmd = Get-Command playwright -ErrorAction SilentlyContinue
if ($null -eq $playwrightCmd) {
  throw "Playwright CLI is required. Install with: npm install -g @playwright/cli@latest"
}

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

$repoRoot = Resolve-Path "$PSScriptRoot\..\.."
$appDir = Join-Path $repoRoot "app"
$buildDir = Join-Path $appDir "build\web"
$outputRoot = Join-Path $repoRoot "output\playwright"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDir = Join-Path $outputRoot "responsive-$timestamp"

$viewports = @(
  @{ Width = 390; Height = 900; Label = "compact" },
  @{ Width = 768; Height = 900; Label = "medium" },
  @{ Width = 1280; Height = 900; Label = "expanded" }
)

$routeList = $Routes.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
if ($routeList.Count -eq 0) {
  throw "No routes were provided."
}

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null

Write-Host "Building Flutter web..."
Push-Location $appDir
try {
  Invoke-Step -Script { flutter build web | Out-Host } -ErrorMessage "flutter build web failed"
} finally {
  Pop-Location
}

Write-Host "Starting local static server on 127.0.0.1:7357..."
$serverProcess = Start-Process `
  -FilePath "python" `
  -ArgumentList "-m", "http.server", "7357", "--directory", $buildDir `
  -PassThru `
  -WindowStyle Hidden

$rows = New-Object System.Collections.Generic.List[object]
$errors = New-Object System.Collections.Generic.List[string]

try {
  Start-Sleep -Seconds 2

  Write-Host "Ensuring Playwright Chromium browser is installed..."
  Push-Location $repoRoot
  try {
    Invoke-Step `
      -Script { playwright install chromium | Out-Host } `
      -ErrorMessage "playwright install chromium failed"
  } finally {
    Pop-Location
  }

  foreach ($route in $routeList) {
    foreach ($viewport in $viewports) {
      $safeRoute = ($route -replace "^/#/", "") -replace "[^A-Za-z0-9/_-]", "-" -replace "/", "__"
      if ([string]::IsNullOrWhiteSpace($safeRoute)) {
        $safeRoute = "root"
      }

      $fileName = "$safeRoute" + "__$($viewport.Width)x$($viewport.Height).png"
      $filePath = Join-Path $outputDir $fileName
      $url = "$BaseUrl$route"

      Write-Host "Capturing $url at $($viewport.Width)x$($viewport.Height)..."
      $started = Get-Date
      Push-Location $repoRoot
      try {
        & playwright screenshot `
          --browser chromium `
          --full-page `
          --wait-for-timeout 1500 `
          --viewport-size "$($viewport.Width),$($viewport.Height)" `
          "$url" `
          "$filePath" | Out-Host
        if ($LASTEXITCODE -ne 0) {
          $errors.Add("Failed screenshot: route=$route viewport=$($viewport.Width)x$($viewport.Height)")
          continue
        }
      } finally {
        Pop-Location
      }
      $duration = [int]((Get-Date) - $started).TotalMilliseconds
      $rows.Add(
        [pscustomobject]@{
          Route = $route
          Viewport = "$($viewport.Width)x$($viewport.Height)"
          Width = $viewport.Width
          Height = $viewport.Height
          DurationMs = $duration
          File = $fileName
        }
      )
    }
  }
} finally {
  if ($null -ne $serverProcess -and -not $serverProcess.HasExited) {
    Stop-Process -Id $serverProcess.Id -Force
  }
}

$reportPath = Join-Path $outputDir "report.md"
$reportLines = @()
$reportLines += "# Responsive QA Report"
$reportLines += ""
$reportLines += "Generated at: $([DateTime]::UtcNow.ToString("o"))"
$reportLines += "Base URL: $BaseUrl"
$reportLines += ""
$reportLines += "## Screenshots"
$reportLines += ""
$reportLines += "| Route | Viewport | Load ms | File |"
$reportLines += "|---|---:|---:|---|"
foreach ($row in $rows) {
  $reportLines += "| ``$($row.Route)`` | $($row.Viewport) | $($row.DurationMs) | ``$($row.File)`` |"
}

$reportLines += ""
$reportLines += "## Capture Errors"
$reportLines += ""
if ($errors.Count -eq 0) {
  $reportLines += "- None"
} else {
  foreach ($error in $errors) {
    $reportLines += "- $error"
  }
}

Set-Content -Path $reportPath -Value $reportLines -Encoding UTF8

if ($errors.Count -gt 0) {
  throw "Responsive QA finished with capture errors. See $reportPath"
}

Write-Host "QA artifacts written to: $outputDir"
Write-Host "QA report: $reportPath"
