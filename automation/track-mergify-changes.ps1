# track-mergify-changes.ps1
# Comprehensive change tracking and audit script for Mergify configurations
# This script monitors, logs, and reports on all changes to Mergify policies and configurations

param(
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = ".mergify",
    
    [Parameter(Mandatory=$false)]
    [string]$ChecklistPath = "checklists",
    
    [Parameter(Mandatory=$false)]
    [string]$AuditLogPath = "audit-logs",
    
    [Parameter(Mandatory=$false)]
    [string]$GitRepository = $env:GITHUB_REPOSITORY,
    
    [Parameter(Mandatory=$false)]
    [string]$GitToken = $env:GITHUB_TOKEN,
    
    [Parameter(Mandatory=$false)]
    [string]$SlackWebhookUrl = $env:SLACK_WEBHOOK_URL,
    
    [Parameter(Mandatory=$false)]
    [string]$AuditApiUrl = $env:AUDIT_API_URL,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("detect", "track", "report", "analyze", "alert")]
    [string]$Action = "detect",
    
    [Parameter(Mandatory=$false)]
    [int]$DaysBack = 30,
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed,
    
    [Parameter(Mandatory=$false)]
    [switch]$SendAlerts
)

# Import required modules
if (Get-Module -ListAvailable -Name PowerShellForGitHub) {
    Import-Module PowerShellForGitHub -ErrorAction SilentlyContinue
}

# Initialize tracking data structure
$script:ChangeTracker = @{
    "StartTime" = Get-Date
    "Repository" = $GitRepository
    "Action" = $Action
    "Changes" = @()
    "Statistics" = @{
        "TotalChanges" = 0
        "ConfigChanges" = 0
        "ChecklistChanges" = 0
        "PolicyChanges" = 0
        "SecurityChanges" = 0
        "BreakingChanges" = 0
    }
    "Alerts" = @()
    "Recommendations" = @()
}

#region Helper Functions

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $colorMap = @{
        "Info" = "Cyan"
        "Warning" = "Yellow" 
        "Error" = "Red"
        "Success" = "Green"
    }
    
    $logEntry = "[$timestamp] [$Level] $Message"
    Write-Host $logEntry -ForegroundColor $colorMap[$Level]
    
    # Write to audit log file
    if (-not (Test-Path $AuditLogPath)) {
        New-Item -Path $AuditLogPath -ItemType Directory -Force | Out-Null
    }
    
    $logFile = Join-Path $AuditLogPath "mergify-changes-$(Get-Date -Format 'yyyy-MM-dd').log"
    Add-Content -Path $logFile -Value $logEntry
}

function Get-GitCommitHistory {
    param(
        [string]$Path,
        [int]$Days = 30
    )
    
    try {
        $sinceDate = (Get-Date).AddDays(-$Days).ToString("yyyy-MM-dd")
        
        # Get git log for Mergify-related files
        $gitLogCmd = "git log --since='$sinceDate' --oneline --name-only --pretty=format:'%H|%an|%ae|%ad|%s' --date=iso -- '$Path'"
        $gitOutput = Invoke-Expression $gitLogCmd 2>$null
        
        if (-not $gitOutput) {
            Write-Log "No git history found for path: $Path" -Level "Warning"
            return @()
        }
        
        $commits = @()
        $currentCommit = $null
        
        foreach ($line in $gitOutput) {
            if ($line -match '^[a-f0-9]{7,40}\|') {
                # New commit line
                if ($currentCommit) {
                    $commits += $currentCommit
                }
                
                $parts = $line -split '\|'
                $currentCommit = @{
                    "Hash" = $parts[0]
                    "Author" = $parts[1]
                    "Email" = $parts[2]
                    "Date" = [DateTime]::Parse($parts[3])
                    "Message" = $parts[4]
                    "Files" = @()
                }
            } elseif ($line -and $line -match '\.(yml|yaml)$') {
                # File in commit
                if ($currentCommit) {
                    $currentCommit.Files += $line.Trim()
                }
            }
        }
        
        # Add the last commit
        if ($currentCommit) {
            $commits += $currentCommit
        }
        
        return $commits
    }
    catch {
        Write-Log "Error getting git history: $($_.Exception.Message)" -Level "Error"
        return @()
    }
}

function Analyze-FileChanges {
    param(
        [string]$FilePath,
        [string]$CommitHash,
        [string]$PreviousCommitHash
    )
    
    try {
        # Get file content at different commits
        $currentContent = ""
        $previousContent = ""
        
        if ($CommitHash) {
            $currentContent = git show "$CommitHash`:$FilePath" 2>$null
        }
        
        if ($PreviousCommitHash) {
            $previousContent = git show "$PreviousCommitHash`:$FilePath" 2>$null
        }
        
        if (-not $currentContent -and (Test-Path $FilePath)) {
            $currentContent = Get-Content $FilePath -Raw
        }
        
        $analysis = @{
            "FilePath" = $FilePath
            "ChangeType" = "Modified"
            "LinesAdded" = 0
            "LinesRemoved" = 0
            "SecurityImpact" = $false
            "BreakingChange" = $false
            "PolicyChanges" = @()
            "RiskLevel" = "Low"
        }
        
        # Determine change type
        if (-not $previousContent) {
            $analysis.ChangeType = "Added"
        } elseif (-not $currentContent) {
            $analysis.ChangeType = "Deleted"
        }
        
        # Analyze content changes
        if ($currentContent -and $previousContent) {
            $currentLines = $currentContent -split "`n"
            $previousLines = $previousContent -split "`n"
            
            # Simple diff analysis
            $analysis.LinesAdded = ($currentLines | Where-Object { $_ -notin $previousLines }).Count
            $analysis.LinesRemoved = ($previousLines | Where-Object { $_ -notin $currentLines }).Count
            
            # Security impact analysis
            $securityPatterns = @(
                'approved-reviews-by',
                'security-team',
                'files~=.*secret',
                'files~=.*credential',
                'emergency',
                'break-glass'
            )
            
            foreach ($pattern in $securityPatterns) {
                $inCurrent = $currentContent -match $pattern
                $inPrevious = $previousContent -match $pattern
                
                if ($inCurrent -ne $inPrevious) {
                    $analysis.SecurityImpact = $true
                    $analysis.PolicyChanges += "Security policy change detected: $pattern"
                    
                    if (-not $inCurrent -and $inPrevious) {
                        # Security control removed
                        $analysis.BreakingChange = $true
                        $analysis.RiskLevel = "High"
                    }
                }
            }
            
            # Breaking change detection
            $breakingPatterns = @(
                'merge:\s*method:',
                'required_status_checks:',
                'dismiss_stale_reviews:',
                'enforce_admins:'
            )
            
            foreach ($pattern in $breakingPatterns) {
                $currentMatch = [regex]::Match($currentContent, $pattern)
                $previousMatch = [regex]::Match($previousContent, $pattern)
                
                if ($currentMatch.Success -and $previousMatch.Success) {
                    if ($currentMatch.Value -ne $previousMatch.Value) {
                        $analysis.BreakingChange = $true
                        $analysis.PolicyChanges += "Breaking change detected in: $pattern"
                        $analysis.RiskLevel = "High"
                    }
                }
            }
            
            # Team/user changes
            $teamPattern = 'teams:\s*-\s*["\']([^"\']+)["\']'
            $currentTeams = [regex]::Matches($currentContent, $teamPattern) | ForEach-Object { $_.Groups[1].Value }
            $previousTeams = [regex]::Matches($previousContent, $teamPattern) | ForEach-Object { $_.Groups[1].Value }
            
            $addedTeams = $currentTeams | Where-Object { $_ -notin $previousTeams }
            $removedTeams = $previousTeams | Where-Object { $_ -notin $currentTeams }
            
            if ($addedTeams) {
                $analysis.PolicyChanges += "Teams added: $($addedTeams -join ', ')"
            }
            if ($removedTeams) {
                $analysis.PolicyChanges += "Teams removed: $($removedTeams -join ', ')"
                $analysis.RiskLevel = "Medium"
            }
        }
        
        return $analysis
    }
    catch {
        Write-Log "Error analyzing file changes for $FilePath`: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

function Send-SlackNotification {
    param(
        [hashtable]$ChangeData
    )
    
    if (-not $SlackWebhookUrl) {
        Write-Log "Slack webhook URL not configured, skipping notification" -Level "Warning"
        return
    }
    
    try {
        $riskColor = switch ($ChangeData.RiskLevel) {
            "High" { "danger" }
            "Medium" { "warning" }
            "Low" { "good" }
            default { "good" }
        }
        
        $message = @{
            "text" = "Mergify Configuration Change Detected"
            "attachments" = @(
                @{
                    "color" = $riskColor
                    "title" = "Repository: $($script:ChangeTracker.Repository)"
                    "fields" = @(
                        @{
                            "title" = "File"
                            "value" = $ChangeData.FilePath
                            "short" = $true
                        },
                        @{
                            "title" = "Change Type"
                            "value" = $ChangeData.ChangeType
                            "short" = $true
                        },
                        @{
                            "title" = "Risk Level"
                            "value" = $ChangeData.RiskLevel
                            "short" = $true
                        },
                        @{
                            "title" = "Security Impact"
                            "value" = if ($ChangeData.SecurityImpact) { "Yes" } else { "No" }
                            "short" = $true
                        }
                    )
                    "footer" = "Mergify Change Tracker"
                    "ts" = [int][double]::Parse((Get-Date -UFormat %s))
                }
            )
        }
        
        if ($ChangeData.PolicyChanges) {
            $message.attachments[0].fields += @{
                "title" = "Policy Changes"
                "value" = ($ChangeData.PolicyChanges -join "`n")
                "short" = $false
            }
        }
        
        $jsonBody = $message | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Uri $SlackWebhookUrl -Method Post -Body $jsonBody -ContentType "application/json"
        
        Write-Log "Slack notification sent successfully" -Level "Success"
    }
    catch {
        Write-Log "Error sending Slack notification: $($_.Exception.Message)" -Level "Error"
    }
}

function Send-AuditLog {
    param(
        [hashtable]$AuditData
    )
    
    if (-not $AuditApiUrl) {
        Write-Log "Audit API URL not configured, skipping audit log" -Level "Warning"
        return
    }
    
    try {
        $headers = @{
            "Content-Type" = "application/json"
            "User-Agent" = "Mergify-Change-Tracker/1.0"
        }
        
        if ($GitToken) {
            $headers["Authorization"] = "Bearer $GitToken"
        }
        
        $auditPayload = @{
            "timestamp" = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
            "repository" = $script:ChangeTracker.Repository
            "event_type" = "mergify_config_change"
            "change_data" = $AuditData
            "metadata" = @{
                "tool" = "mergify-change-tracker"
                "version" = "1.0"
                "environment" = $env:COMPUTERNAME
            }
        }
        
        $jsonPayload = $auditPayload | ConvertTo-Json -Depth 10
        $response = Invoke-RestMethod -Uri $AuditApiUrl -Method Post -Body $jsonPayload -Headers $headers
        
        Write-Log "Audit log sent successfully to $AuditApiUrl" -Level "Success"
    }
    catch {
        Write-Log "Error sending audit log: $($_.Exception.Message)" -Level "Error"
    }
}

function Get-ConfigurationDrift {
    param(
        [string]$Repository
    )
    
    try {
        Write-Log "Checking for configuration drift across repositories..." -Level "Info"
        
        # This would typically query multiple repositories to detect drift
        # For now, we'll check against a baseline configuration
        
        $driftReport = @{
            "Repository" = $Repository
            "DriftDetected" = $false
            "DriftDetails" = @()
            "RecommendedActions" = @()
        }
        
        # Check if repository is using central configuration
        $mergifyFiles = Get-ChildItem -Path $ConfigPath -Filter "*.yml" -ErrorAction SilentlyContinue
        
        foreach ($file in $mergifyFiles) {
            $content = Get-Content $file.FullName -Raw
            
            # Check for extends usage
            if ($content -notmatch 'extends:') {
                $driftReport.DriftDetected = $true
                $driftReport.DriftDetails += "File $($file.Name) does not extend from central configuration"
                $driftReport.RecommendedActions += "Update $($file.Name) to extend from central repository"
            }
            
            # Check for local overrides of security policies
            $securityOverrides = @(
                'approved-reviews-by.*=\s*0',
                'dismiss_stale_reviews:\s*false',
                'enforce_admins:\s*false'
            )
            
            foreach ($override in $securityOverrides) {
                if ($content -match $override) {
                    $driftReport.DriftDetected = $true
                    $driftReport.DriftDetails += "Security policy override detected: $override"
                    $driftReport.RecommendedActions += "Remove local security policy override: $override"
                }
            }
        }
        
        return $driftReport
    }
    catch {
        Write-Log "Error checking configuration drift: $($_.Exception.Message)" -Level "Error"
        return $null
    }
}

function Generate-ChangeReport {
    param(
        [array]$Changes
    )
    
    $reportPath = Join-Path $AuditLogPath "change-report-$(Get-Date -Format 'yyyy-MM-dd-HHmm').html"
    
    $htmlTemplate = @"
<!DOCTYPE html>
<html>
<head>
    <title>Mergify Change Report - $($script:ChangeTracker.Repository)</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #f0f0f0; padding: 20px; border-radius: 5px; }
        .summary { background-color: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .change { border: 1px solid #ddd; margin: 10px 0; padding: 15px; border-radius: 5px; }
        .high-risk { border-left: 5px solid #ff4444; background-color: #fff5f5; }
        .medium-risk { border-left: 5px solid #ffaa00; background-color: #fffcf0; }
        .low-risk { border-left: 5px solid #44ff44; background-color: #f5fff5; }
        .policy-change { background-color: #f0f8ff; padding: 10px; margin: 10px 0; border-radius: 3px; }
        table { width: 100%; border-collapse: collapse; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Mergify Change Report</h1>
        <p><strong>Repository:</strong> $($script:ChangeTracker.Repository)</p>
        <p><strong>Report Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>Period:</strong> Last $DaysBack days</p>
    </div>
    
    <div class="summary">
        <h2>Summary Statistics</h2>
        <table>
            <tr><th>Metric</th><th>Count</th></tr>
            <tr><td>Total Changes</td><td>$($script:ChangeTracker.Statistics.TotalChanges)</td></tr>
            <tr><td>Configuration Changes</td><td>$($script:ChangeTracker.Statistics.ConfigChanges)</td></tr>
            <tr><td>Checklist Changes</td><td>$($script:ChangeTracker.Statistics.ChecklistChanges)</td></tr>
            <tr><td>Security-Related Changes</td><td>$($script:ChangeTracker.Statistics.SecurityChanges)</td></tr>
            <tr><td>Breaking Changes</td><td>$($script:ChangeTracker.Statistics.BreakingChanges)</td></tr>
        </table>
    </div>
    
    <h2>Detailed Changes</h2>
"@
    
    foreach ($change in $Changes) {
        $riskClass = switch ($change.Analysis.RiskLevel) {
            "High" { "high-risk" }
            "Medium" { "medium-risk" }
            "Low" { "low-risk" }
            default { "low-risk" }
        }
        
        $htmlTemplate += @"
    <div class="change $riskClass">
        <h3>$($change.FilePath)</h3>
        <p><strong>Commit:</strong> $($change.Hash) by $($change.Author) on $($change.Date)</p>
        <p><strong>Message:</strong> $($change.Message)</p>
        <p><strong>Change Type:</strong> $($change.Analysis.ChangeType)</p>
        <p><strong>Risk Level:</strong> $($change.Analysis.RiskLevel)</p>
        <p><strong>Security Impact:</strong> $(if ($change.Analysis.SecurityImpact) { 'Yes' } else { 'No' })</p>
        <p><strong>Breaking Change:</strong> $(if ($change.Analysis.BreakingChange) { 'Yes' } else { 'No' })</p>
        
        $(if ($change.Analysis.PolicyChanges) {
            "<div class='policy-change'><strong>Policy Changes:</strong><ul>" +
            ($change.Analysis.PolicyChanges | ForEach-Object { "<li>$_</li>" }) -join "" +
            "</ul></div>"
        })
    </div>
"@
    }
    
    $htmlTemplate += @"
    
    <div class="summary">
        <h2>Recommendations</h2>
        <ul>
"@
    
    foreach ($recommendation in $script:ChangeTracker.Recommendations) {
        $htmlTemplate += "            <li>$recommendation</li>`n"
    }
    
    $htmlTemplate += @"
        </ul>
    </div>
</body>
</html>
"@
    
    $htmlTemplate | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Log "Change report generated: $reportPath" -Level "Success"
    
    return $reportPath
}

#endregion

#region Main Action Functions

function Invoke-ChangeDetection {
    Write-Log "Starting Mergify change detection..." -Level "Info"
    
    # Get git history for configuration files
    $configCommits = Get-GitCommitHistory -Path $ConfigPath -Days $DaysBack
    $checklistCommits = Get-GitCommitHistory -Path $ChecklistPath -Days $DaysBack
    
    $allCommits = @()
    $allCommits += $configCommits
    $allCommits += $checklistCommits
    
    # Sort by date (newest first)
    $allCommits = $allCommits | Sort-Object Date -Descending
    
    Write-Log "Found $($allCommits.Count) commits in the last $DaysBack days" -Level "Info"
    
    $previousCommit = $null
    foreach ($commit in $allCommits) {
        Write-Log "Processing commit: $($commit.Hash) by $($commit.Author)" -Level "Info"
        
        foreach ($file in $commit.Files) {
            # Analyze each changed file
            $analysis = Analyze-FileChanges -FilePath $file -CommitHash $commit.Hash -PreviousCommitHash $previousCommit.Hash
            
            if ($analysis) {
                $changeRecord = @{
                    "Hash" = $commit.Hash
                    "Author" = $commit.Author
                    "Email" = $commit.Email
                    "Date" = $commit.Date
                    "Message" = $commit.Message
                    "FilePath" = $file
                    "Analysis" = $analysis
                }
                
                $script:ChangeTracker.Changes += $changeRecord
                $script:ChangeTracker.Statistics.TotalChanges++
                
                # Update statistics
                if ($file -like "*$ConfigPath*") {
                    $script:ChangeTracker.Statistics.ConfigChanges++
                } elseif ($file -like "*$ChecklistPath*") {
                    $script:ChangeTracker.Statistics.ChecklistChanges++
                }
                
                if ($analysis.SecurityImpact) {
                    $script:ChangeTracker.Statistics.SecurityChanges++
                }
                
                if ($analysis.BreakingChange) {
                    $script:ChangeTracker.Statistics.BreakingChanges++
                }
                
                # Generate alerts for high-risk changes
                if ($analysis.RiskLevel -eq "High") {
                    $alert = @{
                        "Level" = "High"
                        "Message" = "High-risk change detected in $file"
                        "Details" = $analysis.PolicyChanges -join "; "
                        "Author" = $commit.Author
                        "Date" = $commit.Date
                    }
                    
                    $script:ChangeTracker.Alerts += $alert
                    
                    if ($SendAlerts) {
                        Send-SlackNotification -ChangeData $changeRecord
                        Send-AuditLog -AuditData $changeRecord
                    }
                }
            }
        }
        
        $previousCommit = $commit
    }
    
    # Generate recommendations
    if ($script:ChangeTracker.Statistics.BreakingChanges -gt 0) {
        $script:ChangeTracker.Recommendations += "Review breaking changes for potential rollback requirements"
    }
    
    if ($script:ChangeTracker.Statistics.SecurityChanges -gt 5) {
        $script:ChangeTracker.Recommendations += "High number of security changes detected - consider security review"
    }
    
    Write-Log "Change detection completed. Found $($script:ChangeTracker.Statistics.TotalChanges) changes" -Level "Success"
}

function Invoke-ChangeTracking {
    Write-Log "Starting comprehensive change tracking..." -Level "Info"
    
    # First run detection
    Invoke-ChangeDetection
    
    # Check for configuration drift
    $driftReport = Get-ConfigurationDrift -Repository $GitRepository
    
    if ($driftReport -and $driftReport.DriftDetected) {
        Write-Log "Configuration drift detected!" -Level "Warning"
        
        foreach ($detail in $driftReport.DriftDetails) {
            Write-Log "Drift: $detail" -Level "Warning"
        }
        
        $script:ChangeTracker.Recommendations += $driftReport.RecommendedActions
    }
    
    # Generate comprehensive report
    $reportPath = Generate-ChangeReport -Changes $script:ChangeTracker.Changes
    
    Write-Log "Change tracking completed. Report available at: $reportPath" -Level "Success"
}

function Invoke-ChangeReporting {
    Write-Log "Generating change analysis report..." -Level "Info"
    
    Invoke-ChangeDetection
    
    # Console output
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "MERGIFY CHANGE ANALYSIS REPORT" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    Write-Host "`nRepository: $($script:ChangeTracker.Repository)"
    Write-Host "Analysis Period: Last $DaysBack days"
    Write-Host "Report Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    Write-Host "`nSUMMARY STATISTICS:" -ForegroundColor Yellow
    Write-Host "Total Changes: $($script:ChangeTracker.Statistics.TotalChanges)"
    Write-Host "Config Changes: $($script:ChangeTracker.Statistics.ConfigChanges)"
    Write-Host "Checklist Changes: $($script:ChangeTracker.Statistics.ChecklistChanges)"
    Write-Host "Security Changes: $($script:ChangeTracker.Statistics.SecurityChanges)"
    Write-Host "Breaking Changes: $($script:ChangeTracker.Statistics.BreakingChanges)"
    
    if ($script:ChangeTracker.Alerts.Count -gt 0) {
        Write-Host "`nHIGH-RISK ALERTS:" -ForegroundColor Red
        foreach ($alert in $script:ChangeTracker.Alerts) {
            Write-Host "• $($alert.Message) by $($alert.Author) on $($alert.Date)" -ForegroundColor Red
            if ($Detailed) {
                Write-Host "  Details: $($alert.Details)" -ForegroundColor Gray
            }
        }
    }
    
    if ($script:ChangeTracker.Recommendations.Count -gt 0) {
        Write-Host "`nRECOMMENDATIONS:" -ForegroundColor Yellow
        foreach ($rec in $script:ChangeTracker.Recommendations) {
            Write-Host "• $rec" -ForegroundColor Yellow
        }
    }
    
    # Generate HTML report
    Generate-ChangeReport -Changes $script:ChangeTracker.Changes | Out-Null
}

function Invoke-ChangeAnalysis {
    Write-Log "Starting detailed change analysis..." -Level "Info"
    
    Invoke-ChangeDetection
    
    # Advanced analytics
    $authorStats = $script:ChangeTracker.Changes | Group-Object Author | Sort-Object Count -Descending
    $fileStats = $script:ChangeTracker.Changes | Group-Object FilePath | Sort-Object Count -Descending
    $riskStats = $script:ChangeTracker.Changes | Group-Object { $_.Analysis.RiskLevel } | Sort-Object Count -Descending
    
    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "DETAILED CHANGE ANALYSIS" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan
    
    Write-Host "`nTOP AUTHORS BY CHANGE COUNT:" -ForegroundColor Yellow
    $authorStats | Select-Object -First 5 | ForEach-Object {
        Write-Host "• $($_.Name): $($_.Count) changes"
    }
    
    Write-Host "`nMOST FREQUENTLY CHANGED FILES:" -ForegroundColor Yellow
    $fileStats | Select-Object -First 5 | ForEach-Object {
        Write-Host "• $($_.Name): $($_.Count) changes"
    }
    
    Write-Host "`nRISK DISTRIBUTION:" -ForegroundColor Yellow
    $riskStats | ForEach-Object {
        $color = switch ($_.Name) {
            "High" { "Red" }
            "Medium" { "Yellow" }
            "Low" { "Green" }
            default { "Gray" }
        }
        Write-Host "• $($_.Name) Risk: $($_.Count) changes" -ForegroundColor $color
    }
    
    if ($Detailed) {
        Write-Host "`nDETAILED CHANGE LOG:" -ForegroundColor Yellow
        foreach ($change in $script:ChangeTracker.Changes | Sort-Object Date -Descending | Select-Object -First 10) {
            $riskColor = switch ($change.Analysis.RiskLevel) {
                "High" { "Red" }
                "Medium" { "Yellow" }
                "Low" { "Green" }
                default { "Gray" }
            }
            
            Write-Host "`n[$($change.Date.ToString('yyyy-MM-dd HH:mm'))] $($change.FilePath)" -ForegroundColor $riskColor
            Write-Host "  Author: $($change.Author)"
            Write-Host "  Message: $($change.Message)"
            Write-Host "  Risk: $($change.Analysis.RiskLevel)"
            
            if ($change.Analysis.PolicyChanges) {
                Write-Host "  Policy Changes:" -ForegroundColor Gray
                foreach ($policyChange in $change.Analysis.PolicyChanges) {
                    Write-Host "    - $policyChange" -ForegroundColor Gray
                }
            }
        }
    }
}

function Invoke-AlertGeneration {
    Write-Log "Generating alerts for recent changes..." -Level "Info"
    
    Invoke-ChangeDetection
    
    $recentHighRiskChanges = $script:ChangeTracker.Changes | 
        Where-Object { $_.Analysis.RiskLevel -eq "High" -and $_.Date -gt (Get-Date).AddHours(-24) }
    
    $recentBreakingChanges = $script:ChangeTracker.Changes | 
        Where-Object { $_.Analysis.BreakingChange -and $_.Date -gt (Get-Date).AddHours(-24) }
    
    Write-Host "`nALERT SUMMARY (Last 24 hours):" -ForegroundColor Red
    Write-Host "High-Risk Changes: $($recentHighRiskChanges.Count)"
    Write-Host "Breaking Changes: $($recentBreakingChanges.Count)"
    
    if ($recentHighRiskChanges.Count -gt 0 -or $recentBreakingChanges.Count -gt 0) {
        Write-Host "`nIMMEDIATE ATTENTION REQUIRED:" -ForegroundColor Red
        
        foreach ($change in $recentHighRiskChanges) {
            Write-Host "• HIGH RISK: $($change.FilePath) by $($change.Author)" -ForegroundColor Red
            Write-Host "  Message: $($change.Message)" -ForegroundColor Gray
            
            if ($SendAlerts) {
                Send-SlackNotification -ChangeData $change
                Send-AuditLog -AuditData $change
            }
        }
        
        foreach ($change in $recentBreakingChanges) {
            Write-Host "• BREAKING: $($change.FilePath) by $($change.Author)" -ForegroundColor Red
            Write-Host "  Message: $($change.Message)" -ForegroundColor Gray
        }
    } else {
        Write-Host "No critical changes detected in the last 24 hours." -ForegroundColor Green
    }
}

#endregion

#region Main Execution

Write-Log "Mergify Change Tracking Script Started" -Level "Info"
Write-Log "Action: $Action" -Level "Info"
Write-Log "Repository: $GitRepository" -Level "Info"
Write-Log "Config Path: $ConfigPath" -Level "Info"

# Ensure we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Log "Not in a git repository. Please run from repository root." -Level "Error"
    exit 1
}

# Create audit log directory
if (-not (Test-Path $AuditLogPath)) {
    New-Item -Path $AuditLogPath -ItemType Directory -Force | Out-Null
}

# Execute the requested action
switch ($Action) {
    "detect" {
        Invoke-ChangeDetection
    }
    "track" {
        Invoke-ChangeTracking
    }
    "report" {
        Invoke-ChangeReporting
    }
    "analyze" {
        Invoke-ChangeAnalysis
    }
    "alert" {
        Invoke-AlertGeneration
    }
    default {
        Write-Log "Unknown action: $Action" -Level "Error"
        exit 1
    }
}

Write-Log "Mergify Change Tracking Script Completed" -Level "Success"
