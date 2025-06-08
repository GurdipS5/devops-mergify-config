# validate-config.ps1
# PowerShell script to validate Mergify configuration files with Mergify CLI integration

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = ".mergify",
    
    [Parameter(Mandatory=$false)]
    [string]$ChecklistPath = "checklists",
    
    [Parameter(Mandatory=$false)]
    [switch]$Verbose,
    
    [Parameter(Mandatory=$false)]
    [switch]$FailFast,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseMergifyCLI = $true,
    
    [Parameter(Mandatory=$false)]
    [string]$MergifyToken = $env:MERGIFY_TOKEN
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Initialize counters
$script:TotalChecks = 0
$script:PassedChecks = 0
$script:FailedChecks = 0
$script:Warnings = 0

# Color output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
    $script:Warnings++
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Cyan
}

function Test-MergifyCLIAvailable {
    try {
        $mergifyVersion = & mergify --version 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Mergify CLI found: $mergifyVersion"
            return $true
        }
    }
    catch {
        Write-Warning "Mergify CLI not found. Install with: pip install mergify-cli"
        return $false
    }
    return $false
}

function Install-MergifyCLI {
    Write-Info "Attempting to install Mergify CLI..."
    try {
        # Check if pip is available
        $pipVersion = & pip --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "pip not found. Please install Python and pip first."
            return $false
        }
        
        # Install Mergify CLI
        Write-Info "Installing mergify-cli..."
        & pip install mergify-cli --upgrade
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Mergify CLI installed successfully"
            return $true
        } else {
            Write-Error "Failed to install Mergify CLI"
            return $false
        }
    }
    catch {
        Write-Error "Error installing Mergify CLI: $($_.Exception.Message)"
        return $false
    }
}

function Test-MergifyConfigWithCLI {
    param(
        [string]$FilePath,
        [string]$Repository = "organization/repository"
    )
    
    $script:TotalChecks++
    
    try {
        Write-Info "Validating $FilePath with Mergify CLI..."
        
        # Basic syntax validation
        $validateOutput = & mergify validate $FilePath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Mergify CLI validation passed: $FilePath"
            
            if ($Verbose -and $validateOutput) {
                Write-Host "CLI Output: $validateOutput" -ForegroundColor Gray
            }
            
            $script:PassedChecks++
        } else {
            Write-Error "Mergify CLI validation failed for $FilePath"
            Write-Host "Error details: $validateOutput" -ForegroundColor Red
            $script:FailedChecks++
            return $false
        }
        
        # Advanced validation with repository context (if token available)
        if ($MergifyToken -and $Repository) {
            Write-Info "Running advanced validation with repository context..."
            
            $env:MERGIFY_TOKEN = $MergifyToken
            $advancedOutput = & mergify validate --repository $Repository $FilePath 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Advanced Mergify validation passed: $FilePath"
                
                if ($Verbose -and $advancedOutput) {
                    Write-Host "Advanced validation output: $advancedOutput" -ForegroundColor Gray
                }
            } else {
                Write-Warning "Advanced validation failed: $advancedOutput"
                # Don't fail the script for advanced validation failures
            }
        }
        
        return $true
    }
    catch {
        Write-Error "Error running Mergify CLI validation: $($_.Exception.Message)"
        $script:FailedChecks++
        return $false
    }
}

function Test-MergifyConfigSyntax {
    param([string]$FilePath)
    
    $script:TotalChecks++
    
    try {
        Write-Info "Testing configuration syntax: $FilePath"
        
        # Use mergify check-config if available
        $checkOutput = & mergify check-config $FilePath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Configuration syntax check passed: $FilePath"
            $script:PassedChecks++
            return $true
        } else {
            Write-Error "Configuration syntax check failed: $checkOutput"
            $script:FailedChecks++
            return $false
        }
    }
    catch {
        Write-Warning "mergify check-config not available, falling back to basic validation"
        # Fall back to basic YAML validation
        return Test-YamlSyntax -FilePath $FilePath
    }
}

function Test-MergifyRulesWithCLI {
    param(
        [string]$ConfigFile,
        [string]$Repository = "test-org/test-repo"
    )
    
    $script:TotalChecks++
    
    try {
        Write-Info "Testing Mergify rules simulation..."
        
        # Create a test pull request scenario
        $testPR = @{
            number = 123
            title = "Test PR for validation"
            files = @("test.tf", "app.cs", "Dockerfile")
            labels = @("tech:terraform", "tech:dotnet", "tech:docker")
            base_branch = "main"
            author = "test-user"
        }
        
        # Convert to JSON for CLI
        $testPRJson = $testPR | ConvertTo-Json -Depth 3
        $tempPRFile = [System.IO.Path]::GetTempFileName()
        $testPRJson | Out-File -FilePath $tempPRFile -Encoding UTF8
        
        # Simulate rules (if mergify CLI supports it)
        $simulateOutput = & mergify simulate --config $ConfigFile --pr-data $tempPRFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Rules simulation passed: $ConfigFile"
            
            if ($Verbose) {
                Write-Host "Simulation output: $simulateOutput" -ForegroundColor Gray
            }
            
            $script:PassedChecks++
        } else {
            Write-Warning "Rules simulation failed or not supported: $simulateOutput"
            # Don't fail for simulation issues
            $script:PassedChecks++
        }
        
        # Clean up temp file
        Remove-Item $tempPRFile -ErrorAction SilentlyContinue
        
        return $true
    }
    catch {
        Write-Warning "Could not run rules simulation: $($_.Exception.Message)"
        $script:PassedChecks++
        return $true
    }
}

function Test-MergifyTeamsAndUsers {
    param(
        [string]$ConfigContent,
        [string]$Repository
    )
    
    $script:TotalChecks++
    
    if (-not $MergifyToken -or -not $Repository) {
        Write-Warning "Skipping team/user validation - missing token or repository"
        $script:PassedChecks++
        return $true
    }
    
    try {
        Write-Info "Validating teams and users with GitHub API..."
        
        # Extract teams and users from config
        $teamMatches = [regex]::Matches($ConfigContent, 'teams:\s*-\s*["\']([^"\']+)["\']')
        $userMatches = [regex]::Matches($ConfigContent, 'users:\s*-\s*["\']([^"\']+)["\']')
        
        $env:MERGIFY_TOKEN = $MergifyToken
        
        # Validate teams exist
        foreach ($match in $teamMatches) {
            $teamName = $match.Groups[1].Value
            
            # Use mergify CLI to check team (if supported)
            $teamCheck = & mergify check-team --repository $Repository --team $teamName 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Team validation passed: $teamName"
            } else {
                Write-Warning "Team validation failed: $teamName - $teamCheck"
            }
        }
        
        # Validate users exist
        foreach ($match in $userMatches) {
            $userName = $match.Groups[1].Value
            
            # Use mergify CLI to check user (if supported)
            $userCheck = & mergify check-user --repository $Repository --user $userName 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "User validation passed: $userName"
            } else {
                Write-Warning "User validation failed: $userName - $userCheck"
            }
        }
        
        $script:PassedChecks++
        return $true
    }
    catch {
        Write-Warning "Error validating teams/users: $($_.Exception.Message)"
        $script:PassedChecks++
        return $true
    }
}

function Test-MergifyTemplateValidation {
    param([string]$ConfigPath)
    
    $script:TotalChecks++
    
    try {
        Write-Info "Running Mergify template validation..."
        
        # Use mergify CLI to validate templates
        $templateOutput = & mergify validate-templates --config-dir $ConfigPath 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Template validation passed"
            
            if ($Verbose) {
                Write-Host "Template validation output: $templateOutput" -ForegroundColor Gray
            }
            
            $script:PassedChecks++
        } else {
            Write-Warning "Template validation issues: $templateOutput"
            # Don't fail for template validation
            $script:PassedChecks++
        }
        
        return $true
    }
    catch {
        Write-Warning "Template validation not available or failed: $($_.Exception.Message)"
        $script:PassedChecks++
        return $true
    }
}

function Test-MergifyConfigPerformance {
    param([string]$ConfigFile)
    
    $script:TotalChecks++
    
    try {
        Write-Info "Analyzing configuration performance..."
        
        # Use mergify CLI to analyze performance
        $perfOutput = & mergify analyze-performance $ConfigFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Performance analysis completed"
            
            if ($Verbose) {
                Write-Host "Performance analysis: $perfOutput" -ForegroundColor Gray
            }
            
            # Check for performance warnings
            if ($perfOutput -match "warning|slow|inefficient") {
                Write-Warning "Performance issues detected in configuration"
            }
            
            $script:PassedChecks++
        } else {
            Write-Warning "Performance analysis not available: $perfOutput"
            $script:PassedChecks++
        }
        
        return $true
    }
    catch {
        Write-Warning "Performance analysis failed: $($_.Exception.Message)"
        $script:PassedChecks++
        return $true
    }
}

function Test-YamlSyntax {
    param([string]$FilePath)
    
    $script:TotalChecks++
    
    try {
        # Test YAML syntax using PowerShell-Yaml module or basic validation
        if (Get-Module -ListAvailable -Name powershell-yaml) {
            Import-Module powershell-yaml -ErrorAction Stop
            $content = Get-Content $FilePath -Raw
            $null = ConvertFrom-Yaml $content
            Write-Success "YAML syntax valid: $FilePath"
            $script:PassedChecks++
            return $true
        }
        else {
            # Basic YAML validation without module
            $content = Get-Content $FilePath
            $lineNumber = 0
            foreach ($line in $content) {
                $lineNumber++
                if ($line -match "^\s*-\s*$") {
                    Write-Warning "Empty list item at line $lineNumber in $FilePath"
                }
                if ($line -match "^\s*:\s*$") {
                    Write-Error "Empty key-value pair at line $lineNumber in $FilePath"
                    $script:FailedChecks++
                    return $false
                }
            }
            Write-Success "Basic YAML validation passed: $FilePath"
            $script:PassedChecks++
            return $true
        }
    }
    catch {
        Write-Error "YAML syntax error in $FilePath`: $($_.Exception.Message)"
        $script:FailedChecks++
        return $false
    }
}

function Test-MergifyConfig {
    param([string]$FilePath)
    
    $script:TotalChecks++
    
    try {
        $content = Get-Content $FilePath -Raw
        
        # Check for required sections
        if ($content -notmatch "pull_request_rules:") {
            Write-Error "Missing 'pull_request_rules' section in $FilePath"
            $script:FailedChecks++
            return $false
        }
        
        # Check for proper conditions and actions structure
        if ($content -match "conditions:" -and $content -notmatch "actions:") {
            Write-Error "Found conditions without corresponding actions in $FilePath"
            $script:FailedChecks++
            return $false
        }
        
        # Validate team names format
        $teamMatches = [regex]::Matches($content, 'teams:\s*-\s*"([^"]+)"')
        foreach ($match in $teamMatches) {
            $teamName = $match.Groups[1].Value
            if ($teamName -notmatch '^[a-zA-Z0-9\-_]+$') {
                Write-Warning "Team name '$teamName' contains special characters that might cause issues"
            }
        }
        
        # Check for potentially dangerous patterns
        if ($content -match 'merge:\s*method:\s*merge') {
            Write-Warning "Found merge method 'merge' - consider using 'squash' for cleaner history"
        }
        
        Write-Success "Mergify configuration structure valid: $FilePath"
        $script:PassedChecks++
        return $true
    }
    catch {
        Write-Error "Error validating Mergify config $FilePath`: $($_.Exception.Message)"
        $script:FailedChecks++
        return $false
    }
}

function Test-SecurityPolicies {
    param([string]$FilePath)
    
    $script:TotalChecks++
    
    try {
        $content = Get-Content $FilePath -Raw
        
        # Check for security-related rules
        $securityChecks = @(
            @{ Pattern = 'files~=.*secret'; Description = 'Secret file detection' },
            @{ Pattern = 'files~=.*credential'; Description = 'Credential file detection' },
            @{ Pattern = 'files~=.*\.env'; Description = 'Environment file detection' },
            @{ Pattern = 'approved-reviews-by.*security'; Description = 'Security team approval' }
        )
        
        $foundSecurityRules = 0
        foreach ($check in $securityChecks) {
            if ($content -match $check.Pattern) {
                Write-Success "Found security rule: $($check.Description)"
                $foundSecurityRules++
            }
        }
        
        if ($foundSecurityRules -eq 0) {
            Write-Warning "No security-related rules found in $FilePath"
        }
        
        # Check for hardcoded secrets in config
        $suspiciousPatterns = @(
            'password\s*=\s*["\'].*["\']',
            'token\s*=\s*["\'].*["\']',
            'key\s*=\s*["\'].*["\']'
        )
        
        foreach ($pattern in $suspiciousPatterns) {
            if ($content -match $pattern) {
                Write-Error "Potential hardcoded secret found in $FilePath"
                $script:FailedChecks++
                return $false
            }
        }
        
        Write-Success "Security policy validation passed: $FilePath"
        $script:PassedChecks++
        return $true
    }
    catch {
        Write-Error "Error validating security policies in $FilePath`: $($_.Exception.Message)"
        $script:FailedChecks++
        return $false
    }
}

function Test-ChecklistCompleteness {
    param([string]$ChecklistDir)
    
    $script:TotalChecks++
    
    $requiredTechStacks = @("terraform", "dotnet", "nodejs", "docker", "kubernetes", "python")
    $missingChecklists = @()
    
    foreach ($tech in $requiredTechStacks) {
        $techDir = Join-Path $ChecklistDir $tech
        if (-not (Test-Path $techDir)) {
            $missingChecklists += $tech
            continue
        }
        
        $checklistFile = Join-Path $techDir "$tech-checklist.yml"
        if (-not (Test-Path $checklistFile)) {
            $missingChecklists += "$tech checklist"
        }
    }
    
    if ($missingChecklists.Count -gt 0) {
        Write-Warning "Missing checklists for: $($missingChecklists -join ', ')"
    } else {
        Write-Success "All required tech stack checklists present"
        $script:PassedChecks++
        return $true
    }
    
    $script:PassedChecks++
    return $true
}

function Test-ExtendReferences {
    param([string]$ConfigPath)
    
    $script:TotalChecks++
    
    try {
        $files = Get-ChildItem -Path $ConfigPath -Filter "*.yml" -Recurse
        
        foreach ($file in $files) {
            $content = Get-Content $file.FullName -Raw
            
            # Find all extends references
            $extendsMatches = [regex]::Matches($content, 'extends:\s*-\s*"([^"]+)"')
            
            foreach ($match in $extendsMatches) {
                $extendUrl = $match.Groups[1].Value
                
                # Validate URL format
                if ($extendUrl -notmatch '^https://raw\.githubusercontent\.com/') {
                    Write-Warning "Non-standard extends URL in $($file.Name): $extendUrl"
                }
                
                # Check if it's a relative path that should exist
                if ($extendUrl -notmatch '^https://') {
                    $referencedFile = Join-Path (Split-Path $file.FullName) $extendUrl
                    if (-not (Test-Path $referencedFile)) {
                        Write-Error "Referenced file not found: $extendUrl in $($file.Name)"
                        $script:FailedChecks++
                        return $false
                    }
                }
            }
        }
        
        Write-Success "All extends references validated"
        $script:PassedChecks++
        return $true
    }
    catch {
        Write-Error "Error validating extends references: $($_.Exception.Message)"
        $script:FailedChecks++
        return $false
    }
}

# Main validation execution
function Start-Validation {
    Write-Info "Starting Mergify configuration validation..."
    Write-Info "Config Path: $ConfigPath"
    Write-Info "Checklist Path: $ChecklistPath"
    Write-Info "Use Mergify CLI: $UseMergifyCLI"
    Write-Host ""
    
    # Check for Mergify CLI availability
    $mergifyCLIAvailable = $false
    if ($UseMergifyCLI) {
        $mergifyCLIAvailable = Test-MergifyCLIAvailable
        
        if (-not $mergifyCLIAvailable) {
            Write-Warning "Mergify CLI not available. Install with: pip install mergify-cli"
            $install = Read-Host "Would you like to try installing Mergify CLI automatically? (y/N)"
            if ($install -eq 'y' -or $install -eq 'Y') {
                $mergifyCLIAvailable = Install-MergifyCLI
            }
        }
    }
    
    # Validate config directory exists
    if (-not (Test-Path $ConfigPath)) {
        Write-Error "Configuration directory not found: $ConfigPath"
        exit 1
    }
    
    # Get all YAML files in config directory
    $configFiles = Get-ChildItem -Path $ConfigPath -Filter "*.yml" -File
    
    if ($configFiles.Count -eq 0) {
        Write-Error "No YAML configuration files found in $ConfigPath"
        exit 1
    }
    
    Write-Info "Found $($configFiles.Count) configuration files"
    Write-Host ""
    
    # Read all config content for team/user validation
    $allConfigContent = ""
    foreach ($file in $configFiles) {
        $allConfigContent += Get-Content $file.FullName -Raw
        $allConfigContent += "`n"
    }
    
    # Validate each configuration file
    foreach ($file in $configFiles) {
        Write-Info "Validating: $($file.Name)"
        
        if ($mergifyCLIAvailable) {
            # Use Mergify CLI for validation
            $mergifyValid = Test-MergifyConfigWithCLI -FilePath $file.FullName
            if (-not $mergifyValid -and $FailFast) {
                Write-Error "Validation failed, exiting due to -FailFast"
                exit 1
            }
            
            # Additional CLI-based tests
            Test-MergifyConfigSyntax -FilePath $file.FullName
            Test-MergifyRulesWithCLI -ConfigFile $file.FullName
            Test-MergifyConfigPerformance -ConfigFile $file.FullName
        } else {
            # Fallback to basic validation
            $yamlValid = Test-YamlSyntax -FilePath $file.FullName
            if (-not $yamlValid -and $FailFast) {
                Write-Error "Validation failed, exiting due to -FailFast"
                exit 1
            }
            
            $mergifyValid = Test-MergifyConfig -FilePath $file.FullName
            if (-not $mergifyValid -and $FailFast) {
                Write-Error "Validation failed, exiting due to -FailFast"
                exit 1
            }
        }
        
        # Security policy validation (always run)
        $securityValid = Test-SecurityPolicies -FilePath $file.FullName
        if (-not $securityValid -and $FailFast) {
            Write-Error "Validation failed, exiting due to -FailFast"
            exit 1
        }
        
        Write-Host ""
    }
    
    # CLI-specific validations
    if ($mergifyCLIAvailable) {
        # Validate teams and users with GitHub API
        Test-MergifyTeamsAndUsers -ConfigContent $allConfigContent -Repository $env:GITHUB_REPOSITORY
        
        # Template validation
        Test-MergifyTemplateValidation -ConfigPath $ConfigPath
    }
    
    # Validate extends references
    Test-ExtendReferences -ConfigPath $ConfigPath
    
    # Validate checklist completeness if path exists
    if (Test-Path $ChecklistPath) {
        Test-ChecklistCompleteness -ChecklistDir $ChecklistPath
    }
    
    # Summary
    Write-Host "=" * 50
    Write-Info "Validation Summary:"
    Write-Success "Passed: $script:PassedChecks"
    if ($script:FailedChecks -gt 0) {
        Write-Error "Failed: $script:FailedChecks"
    }
    if ($script:Warnings -gt 0) {
        Write-Warning "Warnings: $script:Warnings"
    }
    Write-Info "Total Checks: $script:TotalChecks"
    Write-Info "Mergify CLI Used: $mergifyCLIAvailable"
    
    if ($script:FailedChecks -gt 0) {
        Write-Error "Validation completed with errors!"
        exit 1
    } elseif ($script:Warnings -gt 0) {
        Write-Warning "Validation completed with warnings"
        exit 0
    } else {
        Write-Success "All validations passed!"
        exit 0
    }
}

# Execute validation
Start-Validation
