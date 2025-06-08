# audit-compliance.ps1
# PowerShell script to audit Mergify configuration compliance

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = ".mergify",
    
    [Parameter(Mandatory=$false)]
    [string]$ChecklistPath = "checklists",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFormat = "console", # console, json, csv
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile,
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed
)

# Compliance framework definitions
$ComplianceFrameworks = @{
    "SOX" = @{
        "Name" = "Sarbanes-Oxley Act"
        "Requirements" = @(
            "Financial code changes require dual approval",
            "Audit trail for all production changes", 
            "Segregation of duties in deployment process",
            "Change management documentation"
        )
    }
    "GDPR" = @{
        "Name" = "General Data Protection Regulation"
        "Requirements" = @(
            "Data processing changes require privacy review",
            "Personal data handling verification",
            "Data retention policy compliance",
            "Privacy impact assessment for data changes"
        )
    }
    "SOC2" = @{
        "Name" = "SOC 2 Type II"
        "Requirements" = @(
            "Security controls for infrastructure changes",
            "Access control verification",
            "Change management procedures",
            "Monitoring and logging requirements"
        )
    }
    "ISO27001" = @{
        "Name" = "ISO 27001"
        "Requirements" = @(
            "Information security management",
            "Risk assessment for changes",
            "Security incident response",
            "Access control management"
        )
    }
}

# Initialize audit results
$AuditResults = @{
    "Timestamp" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "ConfigPath" = $ConfigPath
    "ComplianceScore" = 0
    "FrameworkResults" = @{}
    "Findings" = @()
    "Recommendations" = @()
}

function Test-SOXCompliance {
    param([string]$ConfigContent)
    
    $findings = @()
    $score = 0
    $maxScore = 4
    
    # Check for financial code protection
    if ($ConfigContent -match 'files~=.*(financial|billing|payment|accounting)') {
        $score++
        $findings += "✅ Financial file detection rules found"
    } else {
        $findings += "❌ Missing financial file detection rules"
    }
    
    # Check for dual approval on critical changes
    if ($ConfigContent -match '#approved-reviews-by>=2') {
        $score++
        $findings += "✅ Dual approval requirement found"
    } else {
        $findings += "❌ Missing dual approval requirement"
    }
    
    # Check for audit logging
    if ($ConfigContent -match 'webhook.*audit') {
        $score++
        $findings += "✅ Audit logging webhook found"
    } else {
        $findings += "❌ Missing audit logging mechanism"
    }
    
    # Check for change management
    if ($ConfigContent -match 'change.management|ticket') {
        $score++
        $findings += "✅ Change management integration found"
    } else {
        $findings += "❌ Missing change management integration"
    }
    
    return @{
        "Score" = $score
        "MaxScore" = $maxScore
        "Percentage" = [math]::Round(($score / $maxScore) * 100, 2)
        "Findings" = $findings
    }
}

function Test-GDPRCompliance {
    param([string]$ConfigContent)
    
    $findings = @()
    $score = 0
    $maxScore = 4
    
    # Check for privacy-related file detection
    if ($ConfigContent -match 'files~=.*(privacy|gdpr|personal|pii)') {
        $score++
        $findings += "✅ Privacy-related file detection found"
    } else {
        $findings += "❌ Missing privacy file detection rules"
    }
    
    # Check for privacy team review
    if ($ConfigContent -match 'privacy.team|data.protection') {
        $score++
        $findings += "✅ Privacy team review requirement found"
    } else {
        $findings += "❌ Missing privacy team review requirement"
    }
    
    # Check for data impact assessment
    if ($ConfigContent -match 'privacy.impact|data.impact') {
        $score++
        $findings += "✅ Data impact assessment requirement found"
    } else {
        $findings += "❌ Missing data impact assessment requirement"
    }
    
    # Check for data retention compliance
    if ($ConfigContent -match 'retention|data.lifecycle') {
        $score++
        $findings += "✅ Data retention compliance found"
    } else {
        $findings += "❌ Missing data retention compliance checks"
    }
    
    return @{
        "Score" = $score
        "MaxScore" = $maxScore
        "Percentage" = [math]::Round(($score / $maxScore) * 100, 2)
        "Findings" = $findings
    }
}

function Test-SOC2Compliance {
    param([string]$ConfigContent)
    
    $findings = @()
    $score = 0
    $maxScore = 4
    
    # Check for security controls
    if ($ConfigContent -match 'security.team|security.review') {
        $score++
        $findings += "✅ Security review controls found"
    } else {
        $findings += "❌ Missing security review controls"
    }
    
    # Check for access control verification
    if ($ConfigContent -match 'files~=.*(iam|rbac|access|auth)') {
        $score++
        $findings += "✅ Access control file detection found"
    } else {
        $findings += "❌ Missing access control detection"
    }
    
    # Check for infrastructure security
    if ($ConfigContent -match 'label=tech:terraform.*security') {
        $score++
        $findings += "✅ Infrastructure security controls found"
    } else {
        $findings += "❌ Missing infrastructure security controls"
    }
    
    # Check for monitoring requirements
    if ($ConfigContent -match 'monitoring|logging|audit') {
        $score++
        $findings += "✅ Monitoring/logging requirements found"
    } else {
        $findings += "❌ Missing monitoring/logging requirements"
    }
    
    return @{
        "Score" = $score
        "MaxScore" = $maxScore
        "Percentage" = [math]::Round(($score / $maxScore) * 100, 2)
        "Findings" = $findings
    }
}

function Test-ISO27001Compliance {
    param([string]$ConfigContent)
    
    $findings = @()
    $score = 0
    $maxScore = 4
    
    # Check for information security management
    if ($ConfigContent -match 'security.lead|security.team') {
        $score++
        $findings += "✅ Information security management found"
    } else {
        $findings += "❌ Missing information security management"
    }
    
    # Check for risk assessment
    if ($ConfigContent -match 'risk.assessment|security.review') {
        $score++
        $findings += "✅ Risk assessment requirements found"
    } else {
        $findings += "❌ Missing risk assessment requirements"
    }
    
    # Check for incident response
    if ($ConfigContent -match 'incident|emergency|rollback') {
        $score++
        $findings += "✅ Incident response procedures found"
    } else {
        $findings += "❌ Missing incident response procedures"
    }
    
    # Check for access control management
    if ($ConfigContent -match 'approved.reviews.by.*@') {
        $score++
        $findings += "✅ Access control management found"
    } else {
        $findings += "❌ Missing access control management"
    }
    
    return @{
        "Score" = $score
        "MaxScore" = $maxScore
        "Percentage" = [math]::Round(($score / $maxScore) * 100, 2)
        "Findings" = $findings
    }
}

function Test-GeneralSecurityBestPractices {
    param([string]$ConfigContent)
    
    $findings = @()
    $score = 0
    $maxScore = 6
    
    # Check for secret detection
    if ($ConfigContent -match 'secret|credential|key|token') {
        $score++
        $findings += "✅ Secret detection rules found"
    } else {
        $findings += "❌ Missing secret detection rules"
    }
    
    # Check for production protection
    if ($ConfigContent -match 'base=main.*approval') {
        $score++
        $findings += "✅ Production branch protection found"
    } else {
        $findings += "❌ Missing production branch protection"
    }
    
    # Check for infrastructure approval
    if ($ConfigContent -match 'tech:terraform.*devops') {
        $score++
        $findings += "✅ Infrastructure change approval found"
    } else {
        $findings += "❌ Missing infrastructure change approval"
    }
    
    # Check for emergency procedures
    if ($ConfigContent -match 'emergency|break.glass') {
        $score++
        $findings += "✅ Emergency procedures found"
    } else {
        $findings += "❌ Missing emergency procedures"
    }
    
    # Check for dependency scanning
    if ($ConfigContent -match 'security.scan|vulnerability') {
        $score++
        $findings += "✅ Security scanning requirements found"
    } else {
        $findings += "❌ Missing security scanning requirements"
    }
    
    # Check for segregation of duties
    if ($ConfigContent -match '#approved.reviews.by>=2') {
        $score++
        $findings += "✅ Segregation of duties implemented"
    } else {
        $findings += "❌ Missing segregation of duties"
    }
    
    return @{
        "Score" = $score
        "MaxScore" = $maxScore
        "Percentage" = [math]::Round(($score / $maxScore) * 100, 2)
        "Findings" = $findings
    }
}

function Test-MergifyBestPractices {
    param([string]$ConfigContent)
    
    $findings = @()
    $score = 0
    $maxScore = 5
    
    # Check for proper extends usage
    if ($ConfigContent -match 'extends:') {
        $score++
        $findings += "✅ Configuration extends from central repository"
    } else {
        $findings += "❌ Missing extends configuration - not using central repository"
    }
    
    # Check for tech stack detection
    if ($ConfigContent -match 'label=tech:') {
        $score++
        $findings += "✅ Tech stack detection labels found"
    } else {
        $findings += "❌ Missing tech stack detection"
    }
    
    # Check for conditional extends
    if ($ConfigContent -match 'conditionally_extends') {
        $score++
        $findings += "✅ Conditional extends for tech-specific rules found"
    } else {
        $findings += "❌ Missing conditional extends for tech-specific configurations"
    }
    
    # Check for proper webhook usage
    if ($ConfigContent -match 'webhook:') {
        $score++
        $findings += "✅ Webhook integration found"
    } else {
        $findings += "❌ Missing webhook integration for advanced features"
    }
    
    # Check for merge methods
    if ($ConfigContent -match 'method:\s*(squash|rebase)') {
        $score++
        $findings += "✅ Proper merge methods configured (squash/rebase)"
    } else {
        $findings += "❌ Missing or improper merge method configuration"
    }
    
    return @{
        "Score" = $score
        "MaxScore" = $maxScore
        "Percentage" = [math]::Round(($score / $maxScore) * 100, 2)
        "Findings" = $findings
    }
}

function Test-TechStackCoverage {
    param([string]$ConfigContent, [string]$ChecklistPath)
    
    $findings = @()
    $score = 0
    $maxScore = 6
    
    $requiredTechStacks = @("terraform", "dotnet", "nodejs", "docker", "kubernetes", "python")
    
    foreach ($tech in $requiredTechStacks) {
        if ($ConfigContent -match "tech:$tech") {
            $score++
            $findings += "✅ $tech detection rules found"
            
            # Check if checklist exists
            if ((Test-Path $ChecklistPath) -and (Test-Path (Join-Path $ChecklistPath "$tech"))) {
                $findings += "✅ $tech checklist directory exists"
            } else {
                $findings += "⚠️  $tech checklist directory missing"
            }
        } else {
            $findings += "❌ Missing $tech detection rules"
        }
    }
    
    return @{
        "Score" = $score
        "MaxScore" = $maxScore
        "Percentage" = [math]::Round(($score / $maxScore) * 100, 2)
        "Findings" = $findings
    }
}

function Start-ComplianceAudit {
    Write-Host "🔍 Starting Mergify Compliance Audit..." -ForegroundColor Cyan
    Write-Host "Config Path: $ConfigPath" -ForegroundColor Gray
    Write-Host "Output Format: $OutputFormat" -ForegroundColor Gray
    Write-Host ""
    
    # Read all configuration files
    $allConfigContent = ""
    if (Test-Path $ConfigPath) {
        $configFiles = Get-ChildItem -Path $ConfigPath -Filter "*.yml" -Recurse
        foreach ($file in $configFiles) {
            $allConfigContent += Get-Content $file.FullName -Raw
            $allConfigContent += "`n"
        }
    }
    
    if (Test-Path $ChecklistPath) {
        $checklistFiles = Get-ChildItem -Path $ChecklistPath -Filter "*.yml" -Recurse
        foreach ($file in $checklistFiles) {
            $allConfigContent += Get-Content $file.FullName -Raw
            $allConfigContent += "`n"
        }
    }
    
    if ([string]::IsNullOrEmpty($allConfigContent)) {
        Write-Error "No configuration content found to audit"
        exit 1
    }
    
    # Run compliance tests
    Write-Host "Running compliance framework tests..." -ForegroundColor Yellow
    
    $AuditResults.FrameworkResults["SOX"] = Test-SOXCompliance -ConfigContent $allConfigContent
    $AuditResults.FrameworkResults["GDPR"] = Test-GDPRCompliance -ConfigContent $allConfigContent
    $AuditResults.FrameworkResults["SOC2"] = Test-SOC2Compliance -ConfigContent $allConfigContent
    $AuditResults.FrameworkResults["ISO27001"] = Test-ISO27001Compliance -ConfigContent $allConfigContent
    $AuditResults.FrameworkResults["SecurityBestPractices"] = Test-GeneralSecurityBestPractices -ConfigContent $allConfigContent
    $AuditResults.FrameworkResults["MergifyBestPractices"] = Test-MergifyBestPractices -ConfigContent $allConfigContent
    $AuditResults.FrameworkResults["TechStackCoverage"] = Test-TechStackCoverage -ConfigContent $allConfigContent -ChecklistPath $ChecklistPath
    
    # Calculate overall compliance score
    $totalScore = 0
    $totalMaxScore = 0
    foreach ($framework in $AuditResults.FrameworkResults.Keys) {
        $result = $AuditResults.FrameworkResults[$framework]
        $totalScore += $result.Score
        $totalMaxScore += $result.MaxScore
    }
    
    $AuditResults.ComplianceScore = [math]::Round(($totalScore / $totalMaxScore) * 100, 2)
    
    # Generate recommendations
    if ($AuditResults.ComplianceScore -lt 80) {
        $AuditResults.Recommendations += "Overall compliance score is below 80%. Immediate attention required."
    }
    
    if ($AuditResults.FrameworkResults["SOX"].Percentage -lt 75) {
        $AuditResults.Recommendations += "SOX compliance is below 75%. Review financial change controls."
    }
    
    if ($AuditResults.FrameworkResults["SecurityBestPractices"].Percentage -lt 90) {
        $AuditResults.Recommendations += "Security best practices compliance is below 90%. Review security controls."
    }
    
    if ($AuditResults.FrameworkResults["MergifyBestPractices"].Percentage -lt 80) {
        $AuditResults.Recommendations += "Mergify best practices compliance is below 80%. Review configuration architecture."
    }
    
    if ($AuditResults.FrameworkResults["TechStackCoverage"].Percentage -lt 85) {
        $AuditResults.Recommendations += "Tech stack coverage is below 85%. Add missing technology detection rules."
    }
    
    # Output results
    switch ($OutputFormat.ToLower()) {
        "json" {
            $jsonOutput = $AuditResults | ConvertTo-Json -Depth 10
            if ($OutputFile) {
                $jsonOutput | Out-File -FilePath $OutputFile -Encoding UTF8
                Write-Host "Audit results saved to: $OutputFile" -ForegroundColor Green
            } else {
                Write-Output $jsonOutput
            }
        }
        "csv" {
            $csvData = @()
            foreach ($framework in $AuditResults.FrameworkResults.Keys) {
                $result = $AuditResults.FrameworkResults[$framework]
                $csvData += [PSCustomObject]@{
                    Framework = $framework
                    Score = $result.Score
                    MaxScore = $result.MaxScore
                    Percentage = $result.Percentage
                    Status = if ($result.Percentage -ge 80) { "PASS" } else { "FAIL" }
                }
            }
            if ($OutputFile) {
                $csvData | Export-Csv -Path $OutputFile -NoTypeInformation
                Write-Host "Audit results saved to: $OutputFile" -ForegroundColor Green
            } else {
                $csvData | Format-Table -AutoSize
            }
        }
        default {
            # Console output
            Write-Host "=" * 60 -ForegroundColor Cyan
            Write-Host "MERGIFY COMPLIANCE AUDIT REPORT" -ForegroundColor Cyan
            Write-Host "=" * 60 -ForegroundColor Cyan
            Write-Host ""
            Write-Host "Overall Compliance Score: $($AuditResults.ComplianceScore)%" -ForegroundColor $(if ($AuditResults.ComplianceScore -ge 80) { "Green" } else { "Red" })
            Write-Host ""
            
            foreach ($framework in $AuditResults.FrameworkResults.Keys) {
                $result = $AuditResults.FrameworkResults[$framework]
                $status = if ($result.Percentage -ge 80) { "PASS" } else { "FAIL" }
                $color = if ($result.Percentage -ge 80) { "Green" } else { "Red" }
                
                Write-Host "$framework Compliance: $($result.Percentage)% [$status]" -ForegroundColor $color
                
                if ($Detailed) {
                    foreach ($finding in $result.Findings) {
                        Write-Host "  $finding" -ForegroundColor Gray
                    }
                    Write-Host ""
                }
            }
            
            if ($AuditResults.Recommendations.Count -gt 0) {
                Write-Host ""
                Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
                foreach ($recommendation in $AuditResults.Recommendations) {
                    Write-Host "• $recommendation" -ForegroundColor Yellow
                }
            }
            
            Write-Host ""
            Write-Host "Audit completed at: $($AuditResults.Timestamp)" -ForegroundColor Gray
        }
    }
    
    # Exit with appropriate code
    if ($AuditResults.ComplianceScore -lt 80) {
        exit 1
    } else {
        exit 0
    }
}

# Execute audit
Start-ComplianceAudit
