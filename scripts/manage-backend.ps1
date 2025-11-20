param(
    [ValidateSet("start", "stop", "status", "ingest")]
    [string]$Action = "status",

    [string]$Title,
    [string]$RecordingPath = "recordings/automation_test.mp4",
    [int]$DurationSeconds = 12
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptRoot
$venvPython = Join-Path $repoRoot "backend\myenv\Scripts\python.exe"
$uvicornExe = Join-Path $repoRoot "backend\myenv\Scripts\uvicorn.exe"
$stateFile = Join-Path $repoRoot ".backend-state.json"
$envFile = Join-Path $repoRoot ".env"

function Write-Info($message) {
    Write-Host "[backend] $message"
}

function Get-State {
    if (-not (Test-Path $stateFile)) {
        return @{}
    }
    try {
        $raw = Get-Content $stateFile -Raw
        $obj = $raw | ConvertFrom-Json
        if (-not $obj) { return @{} }
        $table = @{}
        foreach ($prop in $obj.PSObject.Properties) {
            $table[$prop.Name] = $prop.Value
        }
        return $table
    } catch {
        return @{}
    }
}

function Save-State($state) {
    ($state | ConvertTo-Json) | Set-Content -Path $stateFile
}

function Is-ProcessAlive($processId) {
    if (-not $processId) { return $false }
    try {
        Get-Process -Id $processId | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Stop-IfRunning($processId, $label) {
    if (Is-ProcessAlive $processId) {
        Write-Info "Stopping $label (PID=$processId)"
        Stop-Process -Id $processId -Force
    }
}

function Load-DotEnv {
    $dict = @{}
    if (-not (Test-Path $envFile)) {
        return $dict
    }
    foreach ($line in Get-Content $envFile) {
        if ($line.Trim().Length -eq 0 -or $line.Trim().StartsWith('#')) { continue }
        $parts = $line -split '=', 2
        if ($parts.Length -eq 2) {
            $name = $parts[0].Trim()
            $value = $parts[1].Trim().Trim('"')
            $dict[$name] = $value
        }
    }
    return $dict
}

function Start-Services {
    if (-not (Test-Path $venvPython)) {
        throw "Virtual environment python not found at $venvPython"
    }

    $state = Get-State

    if (Is-ProcessAlive $state['FastApiPid']) {
        Write-Info "FastAPI already running (PID=$($state['FastApiPid']))"
    } else {
        $fastArgs = @('-m','dotenv','run','--',$venvPython,'-m','uvicorn','backend.fastapi.main:app','--host','0.0.0.0','--port','65514')
        $fastProc = Start-Process -FilePath $venvPython -ArgumentList $fastArgs -WorkingDirectory $repoRoot -PassThru
        $state['FastApiPid'] = $fastProc.Id
        Write-Info "Started FastAPI (PID=$($fastProc.Id))"
    }

    if (Is-ProcessAlive $state['FlaskPid']) {
        Write-Info "Flask/pcd_main already running (PID=$($state['FlaskPid']))"
    } else {
        $flaskArgs = @('-m','dotenv','run','--',$venvPython,'backend\flask_pcd\app.py')
        $flaskProc = Start-Process -FilePath $venvPython -ArgumentList $flaskArgs -WorkingDirectory $repoRoot -PassThru
        $state['FlaskPid'] = $flaskProc.Id
        Write-Info "Started Flask/pcd_main (PID=$($flaskProc.Id))"
    }

    Save-State $state
}

function Stop-Services {
    $state = Get-State
    Stop-IfRunning $state['FastApiPid'] "FastAPI"
    Stop-IfRunning $state['FlaskPid'] "Flask/pcd_main"
    if (Test-Path $stateFile) {
        Remove-Item $stateFile -Force
    }
}

function Show-Status {
    $state = Get-State
    if (Is-ProcessAlive $state['FastApiPid']) {
        Write-Info "FastAPI running (PID=$($state['FastApiPid']))"
    } else {
        Write-Info "FastAPI not running"
    }
    if (Is-ProcessAlive $state['FlaskPid']) {
        Write-Info "Flask/pcd_main running (PID=$($state['FlaskPid']))"
    } else {
        Write-Info "Flask/pcd_main not running"
    }
}

function Invoke-Ingest {
    $envMap = Load-DotEnv
    $apiUrl = $envMap['REPORT_API_URL']
    if (-not $apiUrl) { $apiUrl = 'http://127.0.0.1:65514/reports' }
    $apiKey = $envMap['REPORT_API_KEY']
    if (-not $apiKey) {
        throw "REPORT_API_KEY tidak ditemukan di .env"
    }

    $payloadTitle = if ($Title) { $Title } else { "Laporan Otomatis $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" }
    $payload = [ordered]@{
        title = $payloadTitle
        recording_path = $RecordingPath
        status = 'new'
        duration_seconds = $DurationSeconds
        submitted_by = $envMap['REPORT_SUBMITTED_BY']
        captured_at = (Get-Date).ToString('s')
    }

    $json = $payload | ConvertTo-Json -Depth 4
    Write-Info "POST $apiUrl"
    $response = Invoke-RestMethod -Method Post -Uri $apiUrl -Headers @{ 'Content-Type' = 'application/json'; 'X-Report-Api-Key' = $apiKey } -Body $json
    $response
}

switch ($Action) {
    'start' { Start-Services }
    'stop' { Stop-Services }
    'status' { Show-Status }
    'ingest' {
        $result = Invoke-Ingest
        Write-Info "Report created (id=$($result.id))"
        $result | Format-Table -AutoSize
    }
}
