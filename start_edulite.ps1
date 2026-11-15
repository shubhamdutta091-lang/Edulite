$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$python = Join-Path $projectRoot ".venv\Scripts\python.exe"
$frontend = Join-Path $projectRoot "frontend"
$npm = Get-Command npm.cmd -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    $pythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($null -eq $pythonCommand) {
        throw "Python was not found. Install Python 3.11 or newer, then follow the installation steps in README.md."
    }
    $python = $pythonCommand.Source
}

if ($null -eq $npm) {
    throw "Node.js and npm are required for the Next.js frontend. Install Node.js, then run npm install in the frontend folder."
}
if ($null -eq (Get-Command tesseract.exe -ErrorAction SilentlyContinue) -and
    -not (Test-Path -LiteralPath (Join-Path $env:ProgramFiles "Tesseract-OCR\tesseract.exe") -PathType Leaf)) {
    Write-Output "Tesseract is not installed; scanned-file OCR will use the bundled RapidOCR CPU fallback."
}
if (-not (Test-Path -LiteralPath (Join-Path $frontend "node_modules\next\dist\bin\next") -PathType Leaf)) {
    throw "Next.js dependencies are not installed. Run 'npm install' from the frontend folder first."
}

Push-Location $projectRoot
try {
    & $python -m backend.seed
    if ($LASTEXITCODE -ne 0) {
        throw "EduLite could not initialize its sample database. Install project dependencies with: $python -m pip install -r requirements.txt"
    }

    $apiListener = Get-NetTCPConnection -LocalPort 8000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $apiListener) {
        try {
            $apiHealth = Invoke-RestMethod -Uri "http://127.0.0.1:8000/api/health" -TimeoutSec 3
        }
        catch {
            throw "Port 8000 is already occupied, and its service did not respond as the EduLite API: $($_.Exception.Message)"
        }
        if ($apiHealth.service -ne "EduLite API") {
            throw "Port 8000 is already occupied by a service that is not the EduLite API. Stop it before starting EduLite."
        }
        Write-Output "Using the EduLite API already running on port 8000."
    }
    else {
        Start-Process -FilePath $python `
            -ArgumentList @("-m", "uvicorn", "backend.main:app", "--host", "127.0.0.1", "--port", "8000") `
            -WorkingDirectory $projectRoot
    }

    $frontendListener = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $frontendListener) {
        try {
            $frontendResponse = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 5 -UseBasicParsing
        }
        catch {
            throw "Port 3000 is already occupied, and its service did not respond as the EduLite frontend: $($_.Exception.Message)"
        }
        if ($frontendResponse.Content -notmatch "<title>EduLite") {
            throw "Port 3000 is already occupied by a page that is not the EduLite frontend. Stop it before starting EduLite."
        }
        Write-Output "Using the EduLite frontend already running on port 3000."
    }
    else {
        Start-Process -FilePath $npm.Source `
            -ArgumentList @("run", "dev", "--", "--hostname", "localhost", "--port", "3000") `
            -WorkingDirectory $frontend
    }

    Write-Output "EduLite is starting. Open http://localhost:3000"
    Write-Output "API docs: http://127.0.0.1:8000/docs"
    Write-Output "Close any server windows opened by this script to stop those processes."
}
finally {
    Pop-Location
}
