param(
  [string]$ProjectRef = "",
  [int]$TimeoutSec = 20,
  [switch]$IncludeAuthenticatedChecks,
  [string]$UserJwt = "",
  [string]$ExecutorSecret = ""
)

$ErrorActionPreference = "Stop"

$functions = @(
  "provider_connection_upsert",
  "provider_connection_test",
  "provider_apply_control",
  "executor_tick",
  "plant_sharing_list",
  "plant_sharing_invite",
  "plant_sharing_revoke_invite",
  "plant_sharing_remove_member",
  "plant_sharing_accept_invite"
)

function Resolve-ProjectRef {
  param(
    [string]$ExplicitProjectRef
  )

  if (-not [string]::IsNullOrWhiteSpace($ExplicitProjectRef)) {
    return $ExplicitProjectRef.Trim()
  }

  if (-not [string]::IsNullOrWhiteSpace($env:SUPABASE_PROJECT_REF)) {
    return $env:SUPABASE_PROJECT_REF.Trim()
  }

  $localRefPath = Join-Path $PSScriptRoot "..\..\supabase\.temp\project-ref"
  if (Test-Path $localRefPath) {
    $fromFile = (Get-Content $localRefPath -Raw).Trim()
    if (-not [string]::IsNullOrWhiteSpace($fromFile)) {
      return $fromFile
    }
  }

  throw "Project ref is required. Pass -ProjectRef, set SUPABASE_PROJECT_REF, or run 'supabase link' so supabase/.temp/project-ref exists."
}

$resolvedProjectRef = Resolve-ProjectRef -ExplicitProjectRef $ProjectRef
$baseUrl = "https://$resolvedProjectRef.functions.supabase.co"
$results = New-Object System.Collections.Generic.List[object]

function Invoke-SmokeCheck {
  param(
    [string]$Phase,
    [string]$Name,
    [string]$Method,
    [int[]]$ExpectedStatuses,
    [hashtable]$Headers = @{},
    [string]$Body = ""
  )

  $uri = "$baseUrl/$Name"
  $actualStatus = $null
  $ok = $false
  $errorText = $null

  try {
    $params = @{
      Uri         = $uri
      Method      = $Method
      Headers     = $Headers
      TimeoutSec  = $TimeoutSec
      ErrorAction = "Stop"
    }
    if ($Body -ne "") {
      $params["Body"] = $Body
    }

    $response = Invoke-WebRequest @params
    $actualStatus = [int]$response.StatusCode
    $ok = $ExpectedStatuses -contains $actualStatus
  } catch {
    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
      $actualStatus = [int]$_.Exception.Response.StatusCode
      $ok = $ExpectedStatuses -contains $actualStatus
    } else {
      $actualStatus = -1
      $errorText = $_.Exception.Message
      $ok = $false
    }
  }

  $results.Add([pscustomobject]@{
      Phase      = $Phase
      Function   = $Name
      Method     = $Method
      Expected   = ($ExpectedStatuses -join "|")
      Actual     = $actualStatus
      Passed     = $ok
      Error      = $errorText
      Url        = $uri
    })
}

Write-Host "Running edge function smoke checks against: $baseUrl"

foreach ($name in $functions) {
  Invoke-SmokeCheck `
    -Phase "Unauth" `
    -Name $name `
    -Method "OPTIONS" `
    -ExpectedStatuses @(200) `
    -Headers @{
      "Origin" = "https://example.com"
      "Access-Control-Request-Method" = "POST"
    }

  Invoke-SmokeCheck `
    -Phase "Unauth" `
    -Name $name `
    -Method "GET" `
    -ExpectedStatuses @(405)

  Invoke-SmokeCheck `
    -Phase "Unauth" `
    -Name $name `
    -Method "POST" `
    -ExpectedStatuses @(401) `
    -Headers @{
      "Content-Type" = "application/json"
    } `
    -Body "{}"
}

if ($IncludeAuthenticatedChecks) {
  Write-Host ""
  Write-Host "Running authenticated checks..."

  if ([string]::IsNullOrWhiteSpace($UserJwt)) {
    Write-Host "Skipping user-auth function checks: -UserJwt was not provided." -ForegroundColor Yellow
  } else {
    $userHeaders = @{
      "Content-Type" = "application/json"
      "Authorization" = "Bearer $UserJwt"
    }

    $userAuthFunctions = @(
      "provider_connection_upsert",
      "provider_connection_test",
      "provider_apply_control",
      "plant_sharing_list",
      "plant_sharing_invite",
      "plant_sharing_revoke_invite",
      "plant_sharing_remove_member",
      "plant_sharing_accept_invite"
    )

    foreach ($name in $userAuthFunctions) {
      # Use empty payload to trigger handler-level validation (expected 400)
      # This verifies auth passed and request reached function logic.
      Invoke-SmokeCheck `
        -Phase "Auth" `
        -Name $name `
        -Method "POST" `
        -ExpectedStatuses @(400) `
        -Headers $userHeaders `
        -Body "{}"
    }
  }

  if ([string]::IsNullOrWhiteSpace($ExecutorSecret)) {
    Write-Host "Skipping executor auth check: -ExecutorSecret was not provided." -ForegroundColor Yellow
  } else {
    $executorHeaders = @{
      "Content-Type" = "application/json"
      "Authorization" = "Bearer $ExecutorSecret"
    }

    # For executor_tick we expect a real successful invocation with valid secret.
    Invoke-SmokeCheck `
      -Phase "Auth" `
      -Name "executor_tick" `
      -Method "POST" `
      -ExpectedStatuses @(200) `
      -Headers $executorHeaders `
      -Body "{}"
  }
}

$results | Sort-Object Phase, Function, Method | Format-Table -AutoSize

$failed = $results | Where-Object { -not $_.Passed }
if ($failed.Count -gt 0) {
  Write-Host ""
  Write-Host "Smoke test FAILED ($($failed.Count) checks failed)." -ForegroundColor Red
  exit 1
}

Write-Host ""
Write-Host "Smoke test passed ($($results.Count) checks)." -ForegroundColor Green
