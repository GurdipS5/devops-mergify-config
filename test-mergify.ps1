# Mergify Local Validation Script (PowerShell)
# This script runs all validation checks locally before pushing

param(
    [switch]$SkipDependencyCheck
)

# Color functions
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }

function Write-Header {
    param($Title)
    Write-Host ""
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
}

# Check if required tools are installed
function Test-Dependencies {
    Write-Header "Checking Dependencies"
    
    $missingDeps = @()
    
    # Check yamllint
    try {
        $null = Get-Command yamllint -ErrorAction Stop
        Write-Success "✓ yamllint is installed"
    }
    catch {
        $missingDeps += "yamllint (install: pip install yamllint)"
    }
    
    # Check mergify-cli
    try {
        $null = Get-Command mergify -ErrorAction Stop
        Write-Success "✓ mergify-cli is installed"
    }
    catch {
        $missingDeps += "mergify-cli (install: pip install mergify-cli)"
    }
    
    # Check node
    try {
        $null = Get-Command node -ErrorAction Stop
        Write-Success "✓ node is installed"
    }
    catch {
        $missingDeps += "node (install: https://nodejs.org/)"
    }
    
    # Check python
    try {
        $null = Get-Command python -ErrorAction Stop
        Write-Success "✓ python is installed"
    }
    catch {
        $missingDeps += "python (install: https://python.org/)"
    }
    
    # Check for Node.js packages
    try {
        node -e "require('js-yaml')" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ js-yaml is installed"
        }
        else {
            $missingDeps += "js-yaml (install: npm install -g js-yaml)"
        }
    }
    catch {
        $missingDeps += "js-yaml (install: npm install -g js-yaml)"
    }
    
    # Check for Python packages
    try {
        python -c "import yaml" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ PyYAML is installed"
        }
        else {
            $missingDeps += "PyYAML (install: pip install pyyaml)"
        }
    }
    catch {
        $missingDeps += "PyYAML (install: pip install pyyaml)"
    }
    
    if ($missingDeps.Count -gt 0) {
        Write-Error "`n❌ Missing dependencies:"
        foreach ($dep in $missingDeps) {
            Write-Host "   - $dep"
        }
        Write-Host ""
        Write-Warning "Install missing dependencies and try again."
        return $false
    }
    
    Write-Success "`n✓ All dependencies are installed"
    return $true
}

# Check if .mergify.yml exists
function Test-MergifyFile {
    if (-not (Test-Path ".mergify.yml")) {
        Write-Error "❌ Error: .mergify.yml not found in current directory"
        Write-Warning "Run this script from your repository root."
        return $false
    }
    return $true
}

# Run all validation checks
function Invoke-Validations {
    $failed = 0
    
    # 1. YAML Syntax
    Write-Header "1️⃣  Validating YAML Syntax"
    try {
        yamllint -d "{extends: default, rules: {line-length: {max: 120}}}" .mergify.yml
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ YAML syntax is valid"
        }
        else {
            Write-Error "❌ YAML syntax validation failed"
            $failed = 1
        }
    }
    catch {
        Write-Error "❌ YAML syntax validation failed: $_"
        $failed = 1
    }
    
    # 2. Mergify Configuration
    Write-Header "2️⃣  Validating Mergify Configuration"
    try {
        mergify validate .mergify.yml
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✅ Mergify configuration is valid"
        }
        else {
            Write-Error "❌ Mergify configuration validation failed"
            $failed = 1
        }
    }
    catch {
        Write-Error "❌ Mergify configuration validation failed: $_"
        $failed = 1
    }
    
    # 3. Rule Tests
    Write-Header "3️⃣  Running Rule Tests"
    if (Test-Path ".github/scripts/test-mergify-rules.js") {
        try {
            node .github/scripts/test-mergify-rules.js
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✅ Rule tests passed"
            }
            else {
                Write-Error "❌ Rule tests failed"
                $failed = 1
            }
        }
        catch {
            Write-Error "❌ Rule tests failed: $_"
            $failed = 1
        }
    }
    else {
        Write-Warning "⚠️  Rule test script not found, skipping"
    }
    
    # 4. Best Practices
    Write-Header "4️⃣  Checking Best Practices"
    if (Test-Path ".github/scripts/check-mergify-best-practices.py") {
        try {
            python .github/scripts/check-mergify-best-practices.py
            if ($LASTEXITCODE -eq 0) {
                Write-Success "✅ Best practices check passed"
            }
            else {
                Write-Error "❌ Best practices check failed"
                $failed = 1
            }
        }
        catch {
            Write-Error "❌ Best practices check failed: $_"
            $failed = 1
        }
    }
    else {
        Write-Warning "⚠️  Best practices script not found, skipping"
    }
    
    # 5. Security Scan
    Write-Header "5️⃣  Running Security Scan"
    $sensitivePattern = Select-String -Path .mergify.yml -Pattern '(password|secret|token|api[_-]?key)' -CaseSensitive:$false
    if ($sensitivePattern) {
        Write-Error "❌ Potential sensitive data found in .mergify.yml"
        Write-Warning "Review your configuration for hardcoded secrets"
        $failed = 1
    }
    else {
        Write-Success "✅ No sensitive data patterns detected"
    }
    
    return $failed
}

# Main execution
function Main {
    Write-Info @"

╔═══════════════════════════════════════╗
║   Mergify Local Validation Suite     ║
╚═══════════════════════════════════════╝
"@
    
    # Check if file exists
    if (-not (Test-MergifyFile)) {
        exit 1
    }
    
    # Check dependencies
    if (-not $SkipDependencyCheck) {
        if (-not (Test-Dependencies)) {
            exit 1
        }
    }
    
    Write-Host ""
    Write-Info "Starting validation checks..."
    Write-Host ""
    
    # Run validations
    $failed = Invoke-Validations
    
    if ($failed -eq 0) {
        Write-Header "✨ Success!"
        Write-Success "All validation checks passed! 🎉"
        Write-Success "Your Mergify configuration is ready to push."
        Write-Host ""
        exit 0
    }
    else {
        Write-Header "❌ Validation Failed"
        Write-Error "Some checks failed. Please fix the issues above."
        Write-Host ""
        exit 1
    }
}

# Handle Ctrl+C
try {
    Main
}
catch {
    Write-Host ""
    Write-Warning "Validation interrupted."
    exit 130
}
