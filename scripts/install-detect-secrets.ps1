#!/usr/bin/env pwsh

# Script to install detect-secrets and configure pre-commit hook

Write-Host "Installing detect-secrets pre-commit hook..." -ForegroundColor Cyan

# Check if python3 is available
$pythonCmd = $null
if (Get-Command python3 -ErrorAction SilentlyContinue) {
    $pythonCmd = "python3"
    Write-Host "Found python3" -ForegroundColor Green
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    # Check if python points to version 3.x
    $pythonVersion = & python --version 2>&1
    if ($pythonVersion -match "Python 3\.") {
        $pythonCmd = "python"
        Write-Host "Found python (version 3.x)" -ForegroundColor Green
    } else {
        Write-Host "ERROR: Python 3 is required but not found on PATH" -ForegroundColor Red
        Write-Host "Found: $pythonVersion" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "ERROR: Python is not found on PATH" -ForegroundColor Red
    exit 1
}

# Install detect-secrets
Write-Host "Installing detect-secrets via pip..." -ForegroundColor Cyan
& $pythonCmd -m pip install detect-secrets
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to install detect-secrets" -ForegroundColor Red
    exit 1
}
Write-Host "detect-secrets installed successfully" -ForegroundColor Green

# Configure pre-commit hook
$preCommitPath = ".git\hooks\pre-commit"
$hookContent = @"
######## DETECT-SECRETS-HOOK START ########

echo "Running detect-secrets-hook"

git diff --staged --name-only -z | xargs -0 detect-secrets-hook --baseline .secrets.baseline --exclude-files package-lock.json

echo "Completed detect-secrets-hook"

####### DETECT-SECRETS-HOOK END #######
"@

if (Test-Path $preCommitPath) {
    Write-Host "Pre-commit hook file exists, updating..." -ForegroundColor Cyan
    $existingContent = Get-Content $preCommitPath -Raw

    # Check if detect-secrets hook already exists
    if ($existingContent -match "DETECT-SECRETS-HOOK START") {
        Write-Host "detect-secrets hook already exists in pre-commit file" -ForegroundColor Yellow
    } else {
        # Insert after #!/bin/sh if it exists, otherwise at the beginning
        if ($existingContent -match "^#!/bin/sh") {
            $newContent = $existingContent -replace "(#!/bin/sh)", "`$1`n`n$hookContent"
        } else {
            $newContent = $hookContent + "`n`n" + $existingContent
        }
        Set-Content -Path $preCommitPath -Value $newContent -NoNewline
        Write-Host "Pre-commit hook updated successfully" -ForegroundColor Green
    }
} else {
    Write-Host "Creating new pre-commit hook..." -ForegroundColor Cyan
    $newContent = @"
#!/bin/sh

$hookContent
"@
    # Ensure the hooks directory exists
    $hooksDir = Split-Path $preCommitPath -Parent
    if (-not (Test-Path $hooksDir)) {
        New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    }
    Set-Content -Path $preCommitPath -Value $newContent -NoNewline
    Write-Host "Pre-commit hook created successfully" -ForegroundColor Green
}

Write-Host "`ndetect-secrets pre-commit hook installation complete!" -ForegroundColor Green

