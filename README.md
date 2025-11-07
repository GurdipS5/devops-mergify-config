# devops-mergify-config

> **Automated merge protection with smart dependency management for TeamCity users**

[![TeamCity](https://img.shields.io/badge/CI-TeamCity-blue.svg)](https://www.jetbrains.com/teamcity/)
[![Mergify](https://img.shields.io/badge/Automation-Mergify-green.svg)](https://mergify.com)
[![Renovate](https://img.shields.io/badge/Dependencies-Renovate-orange.svg)](https://renovatebot.com)
[![PowerShell](https://img.shields.io/badge/Scripts-PowerShell-blue.svg)](https://docs.microsoft.com/powershell/)

## 🎯 What This Package Does

This package provides **production-ready Mergify configuration** that:

- ✅ **Integrates with TeamCity** - Reads TeamCity build status to auto-merge PRs
- ✅ **Automates Renovate/Bolt** - Patches merge without approval, majors need review
- ✅ **Enforces quality** - 2 approvals for main, all checks must pass
- ✅ **Saves time** - Auto-labels, auto-assigns teams, auto-deletes branches
- ✅ **Stays safe** - WIP protection, security reviews, linear history required
- ✅ **Works on Windows** - PowerShell scripts included

## 🚀 Quick Start

### Choose Your Path

<table>
<tr>
<td width="50%">

**🪟 Windows User?**

Start here: [**WINDOWS-SETUP.md**](WINDOWS-SETUP.md)

Then: [**QUICKSTART.md**](QUICKSTART.md)

</td>
<td width="50%">

**🐧 macOS/Linux User?**

Start here: [**QUICKSTART.md**](QUICKSTART.md)

Or: [**START-HERE.md**](START-HERE.md)

</td>
</tr>
<tr>
<td width="50%">

**🔧 Need TeamCity Setup?**

Complete guide: [**TEAMCITY-SETUP.md**](TEAMCITY-SETUP.md)

</td>
<td width="50%">

**🤖 Using Renovate/Bolt?**

Integration guide: [**RENOVATE-BOLT-GUIDE.md**](RENOVATE-BOLT-GUIDE.md)

</td>
</tr>
</table>

### 30-Second Overview

```powershell
# 1. Copy files to your repo
Copy-Item -Recurse /path/to/package/* /your/repo/

# 2. Customize .mergify.yml
notepad .mergify.yml  # Update team names, check names

# 3. Configure TeamCity
# Add "Commit Status Publisher" in TeamCity build features

# 4. Test locally
.\test-mergify.ps1

# 5. Deploy!
git add . && git commit -m "Add Mergify" && git push
```

## 📦 What's Included

### Core Configuration Files
```
.mergify.yml              → Main Mergify configuration (TeamCity-ready)
.teamcity/settings.kts    → TeamCity Kotlin DSL examples
test-mergify.ps1          → PowerShell validation script
```

### Documentation (9 Comprehensive Guides)
```
START-HERE.md                  → 📍 Complete overview & file index
WINDOWS-SETUP.md               → 🪟 Windows/PowerShell setup guide
TEAMCITY-SETUP.md             → 🔧 TeamCity integration (detailed)
RENOVATE-BOLT-GUIDE.md        → 🤖 Renovate/Bolt automation
QUICKSTART.md                 → ⚡ Fast setup checklist
QUICK-REFERENCE.md            → 📄 One-page cheat sheet (print this!)
TEAMCITY-UPDATE-SUMMARY.md    → What changed for TeamCity
POWERSHELL-UPDATE.md          → What changed for PowerShell
INDEX.md                      → Complete file directory
```

### Test Scripts
```
.github/scripts/test-mergify-rules.js              → Node.js tests
.github/scripts/check-mergify-best-practices.py    → Python checks
```

### Configuration Examples
```
package.json.example       → NPM scripts
.eslintrc.json.example    → ESLint config
.prettierrc.example       → Prettier config
```

## ✨ Key Features

### 🔒 Merge Protection Rules

| Branch | Approvals | CI Checks | Auto-Merge |
|--------|-----------|-----------|------------|
| **main** | 2 | TeamCity | After approvals |
| **hotfix** | 1 | TeamCity | Expedited |
| **develop** | 1 | TeamCity | After approval |

### 🤖 Smart Dependency Automation

| Update Type | Example | Approval Required? | Auto-Merge? | Speed |
|-------------|---------|-------------------|-------------|-------|
| **Patch** | 1.2.3 → 1.2.4 | ❌ No | ✅ Yes | ~5 min |
| **Security** | Any `[SECURITY]` | ❌ No | ✅ Yes | ~5 min |
| **Minor** | 1.2.3 → 1.3.0 | ✅ 1 approval | ✅ Yes | ~5 min + review |
| **Major** | 1.2.3 → 2.0.0 | ✅ 1 approval + review | ✅ Yes | Variable |

**Result:** Patch updates merge in ~5 minutes with **zero human interaction**! 🎉

### 🏷️ Automatic Labeling

Every PR gets labeled automatically:
- `backend` / `frontend` / `documentation` (by file changes)
- `dependencies` + `patch-update` / `minor-update` / `major-update` (for deps)
- `large-pr` (20+ files changed)
- `security-review` (auth-related changes)

### 👥 Team-Based Reviews

```yaml
backend/ changes  → @backend-team
frontend/ changes → @frontend-team
auth/ changes     → @security-team
```

### 🛡️ Safety Features

- ✅ Draft PRs blocked from merge
- ✅ `work-in-progress` label blocks merge
- ✅ `do-not-merge` label blocks merge
- ✅ Changes requested blocks merge
- ✅ Linear history required (no merge commits)
- ✅ Stale reviews dismissed on new commits
- ✅ Auto-delete branches after merge

## 🔧 TeamCity Integration

### How It Works

```
Developer creates PR
        ↓
TeamCity triggers builds
        ↓
TeamCity Commit Status Publisher
        ↓
GitHub shows "TeamCity" check
        ↓
Mergify reads check status
        ↓
All conditions met? → Auto-merge!
```

### Setup (5 minutes)

1. **TeamCity:** Build Configuration → Build Features
2. **Add:** "Commit Status Publisher"
3. **Select:** GitHub
4. **Configure:** Personal access token (needs `repo:status`)
5. **Add VCS Trigger:** Branch filter `+:pull/*`

**Detailed instructions:** [TEAMCITY-SETUP.md](TEAMCITY-SETUP.md)

### Check Names

The default configuration uses:
```yaml
check-success=TeamCity
```

This works with TeamCity's default status reporting. To find your exact check names:

1. Create a test PR
2. Look at the "Checks" tab
3. Copy the exact name shown
4. Update `.mergify.yml`

**See:** [TEAMCITY-SETUP.md](TEAMCITY-SETUP.md) for details

## 🤖 Renovate & Bolt Automation

### Decision Flow

```
Renovate/Bolt creates PR
        ↓
Is it a PATCH update? ──Yes──→ Auto-approved & merged (~5 min)
        │
        No
        ↓
Is it a MINOR update? ──Yes──→ Needs 1 approval → Auto-merged
        │
        No
        ↓
Is it a MAJOR update? ──Yes──→ Needs 1 approval + review → Auto-merged
```

### Labeling Strategy

All dependency PRs automatically get labeled:
- `dependencies` (all updates)
- `patch-update` / `minor-update` / `major-update`

This makes it easy to:
- Filter PRs by update type
- Set up custom notifications
- Track dependency health

**Complete guide:** [RENOVATE-BOLT-GUIDE.md](RENOVATE-BOLT-GUIDE.md)

## 🪟 Windows Support

This package is **fully compatible with Windows** using PowerShell scripts!

### Setup (Windows)

```powershell
# 1. Enable script execution (run as Administrator)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# 2. Install dependencies
pip install yamllint mergify-cli pyyaml
npm install -g js-yaml

# 3. Run validation
.\test-mergify.ps1
```

**Full guide:** [WINDOWS-SETUP.md](WINDOWS-SETUP.md)

### PowerShell Features

- ✅ Color-coded output (green/red/yellow/blue)
- ✅ Comprehensive error messages
- ✅ Dependency verification
- ✅ Works on Windows, macOS, Linux (with PowerShell 7+)

## 🧪 Testing & Validation

### Local Validation

```powershell
# Run all checks
.\test-mergify.ps1
```

This validates:
1. ✅ YAML syntax
2. ✅ Mergify configuration
3. ✅ Rule structure (10+ tests)
4. ✅ Best practices (14+ checks)
5. ✅ Security scan

### What Gets Checked

- Rule names are unique
- All rules have conditions and actions
- Queue configuration is valid
- No conflicting conditions
- Required checks are consistent
- Security patterns detected
- No sensitive data in config

## 📋 Customization

### Essential Customizations

Before deploying, update `.mergify.yml`:

#### 1. Team Names
```yaml
# Find and replace:
backend-team → your-backend-team
frontend-team → your-frontend-team
security-team → your-security-team
```

#### 2. Check Names
```yaml
# Update to match your TeamCity status:
check-success=TeamCity  # Default
# Or specific:
check-success=TeamCity: Tests
check-success=TeamCity: Lint
```

#### 3. Branch Names
```yaml
# If not using 'main':
base=main → base=master  # or your default branch
```

#### 4. File Patterns
```yaml
# Update paths to match your structure:
^backend/ → ^src/backend/
^frontend/ → ^src/frontend/
^docs/ → ^documentation/
```

### Common Modifications

**Require 3 approvals:**
```yaml
- "#approved-reviews-by>=3"  # Instead of >=2
```

**Add custom label:**
```yaml
- name: Label database changes
  conditions:
    - files~=^database/
  actions:
    label:
      add:
        - database
```

**Disable patch auto-merge:**
```yaml
# Comment out or remove the "Auto-merge Renovate patch updates" rule
```

**Add notification:**
```yaml
- name: Notify on major updates
  conditions:
    - label=major-update
  actions:
    comment:
      message: "@team Major dependency update needs review!"
```

## 🐛 Troubleshooting

### TeamCity status not showing in GitHub

**Cause:** Commit Status Publisher not configured

**Solution:**
1. TeamCity → Build Configuration → Build Features
2. Add "Commit Status Publisher"
3. Select GitHub and add token

### Mergify says "check not found"

**Cause:** Check name mismatch

**Solution:**
1. Look at GitHub PR → Checks tab
2. Note exact name (case-sensitive!)
3. Update `.mergify.yml` with exact name

### PowerShell script won't run

**Cause:** Script execution disabled

**Solution:**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### TeamCity not triggering on PRs

**Cause:** VCS trigger not configured

**Solution:**
1. TeamCity → Triggers → Add VCS Trigger
2. Set branch filter: `+:pull/*`
3. Ensure branch spec includes: `+:refs/pull/*/head`

**More solutions:** Each guide has a troubleshooting section

## 📚 Documentation Index

### Getting Started
- 📍 [**START-HERE.md**](START-HERE.md) - Complete overview (start here!)
- ⚡ [**QUICKSTART.md**](QUICKSTART.md) - Fast setup checklist
- 🪟 [**WINDOWS-SETUP.md**](WINDOWS-SETUP.md) - Windows/PowerShell guide

### Integration Guides
- 🔧 [**TEAMCITY-SETUP.md**](TEAMCITY-SETUP.md) - TeamCity integration (detailed)
- 🤖 [**RENOVATE-BOLT-GUIDE.md**](RENOVATE-BOLT-GUIDE.md) - Renovate/Bolt automation

### Reference
- 📄 [**QUICK-REFERENCE.md**](QUICK-REFERENCE.md) - One-page cheat sheet
- 📖 [**INDEX.md**](INDEX.md) - Complete file directory

### What Changed
- 🔄 [**TEAMCITY-UPDATE-SUMMARY.md**](TEAMCITY-UPDATE-SUMMARY.md) - TeamCity changes
- 🔄 [**RENOVATE-UPDATE-SUMMARY.md**](RENOVATE-UPDATE-SUMMARY.md) - Renovate changes
- 🔄 [**POWERSHELL-UPDATE.md**](POWERSHELL-UPDATE.md) - PowerShell changes

## 🎓 Examples

### Example Workflow: Patch Update

```
1. Renovate creates PR: "fix(deps): update lodash to v4.17.22 [SECURITY]"
   ↓
2. TeamCity runs tests (5 min)
   ↓
3. TeamCity reports success to GitHub
   ↓
4. Mergify auto-approves (patch update)
   ↓
5. Mergify adds labels: dependencies, patch-update
   ↓
6. Mergify merges to queue
   ↓
7. PR merged, branch deleted
   
Total time: ~5 minutes, ZERO human interaction! 🎉
```

### Example Workflow: Feature PR

```
1. Developer creates PR
   ↓
2. Mergify labels: backend, large-pr
   ↓
3. Mergify requests: @backend-team review
   ↓
4. TeamCity runs tests
   ↓
5. Reviewer 1 approves
   ↓
6. Reviewer 2 approves
   ↓
7. TeamCity passes
   ↓
8. Mergify auto-merges
   ↓
9. Branch auto-deleted

Total time: ~10 min + review time
```

## 🔐 Security

### What's Protected

- ✅ No hardcoded secrets (security scan included)
- ✅ Auth changes require security team review
- ✅ All PRs require CI checks to pass
- ✅ Approved by default for docs only (safe)

### Security Scan

The validation script checks for:
- Hardcoded passwords
- API keys
- Tokens
- Secret patterns

Run: `.\test-mergify.ps1`

## 🤝 Contributing

### Before You Push

```powershell
# 1. Test locally
.\test-mergify.ps1

# 2. Verify all checks pass
# If any fail, fix issues

# 3. Commit and push
git add .mergify.yml
git commit -m "Update Mergify config"
git push
```

### Creating a PR

1. Create feature branch
2. Make changes to `.mergify.yml`
3. Test locally
4. Push and create PR
5. TeamCity will validate
6. Get required approvals
7. Mergify auto-merges!

## 💡 Best Practices

1. **Start simple** - Use `check-success=TeamCity` initially
2. **Test first** - Always run `.\test-mergify.ps1` before pushing
3. **Monitor queue** - Check Mergify dashboard weekly
4. **Keep builds fast** - Target <10 min for CI
5. **Review majors** - Major dependency updates need attention
6. **Use labels** - Labels help organize and filter PRs
7. **Trust patches** - If tests pass, patches are safe
8. **Document exceptions** - Add comments for custom rules

## 📊 Monitoring

### Mergify Dashboard

```
https://dashboard.mergify.com/github/<your-org>/<your-repo>
```

View:
- Merge queue status
- Rule evaluations
- Auto-merge history
- Performance metrics

### GitHub Commands

```powershell
# View all dependency PRs
gh pr list --label dependencies

# View PRs needing approval
gh pr list --label minor-update
gh pr list --label major-update

# View recent auto-merges
gh pr list --state merged --author renovate[bot] --limit 20

# Check TeamCity status
gh api repos/OWNER/REPO/commits/SHA/status
```

## 🚀 Ready to Deploy?

### Final Checklist

- [ ] Read START-HERE.md or QUICKSTART.md
- [ ] Install dependencies (Python, Node.js)
- [ ] Copy files to your repository
- [ ] Customize `.mergify.yml` (teams, checks, paths)
- [ ] Configure TeamCity Commit Status Publisher
- [ ] Test locally: `.\test-mergify.ps1`
- [ ] Push to repository
- [ ] Create test PR
- [ ] Verify TeamCity triggers
- [ ] Verify Mergify recognizes checks
- [ ] Watch the automation! ✨

### Need Help?

- 💬 Check the troubleshooting sections in each guide
- 📖 Review [TEAMCITY-SETUP.md](TEAMCITY-SETUP.md) for integration help
- 🐛 Issues with Windows? See [WINDOWS-SETUP.md](WINDOWS-SETUP.md)
- 🤖 Dependency automation? See [RENOVATE-BOLT-GUIDE.md](RENOVATE-BOLT-GUIDE.md)

## 📜 License

Use freely in your projects! This configuration is provided as-is for your use.

## 🙏 Credits

This package integrates:
- [Mergify](https://mergify.com) - Merge automation
- [TeamCity](https://www.jetbrains.com/teamcity/) - CI/CD
- [Renovate](https://renovatebot.com) - Dependency updates
- [Mend Bolt](https://www.mend.io/bolt/) - Dependency updates

## 🎉 What You Get

After deploying this package:

✨ **Automated dependency merges** (patches merge without approval!)
🔒 **Strong merge protections** (2 approvals + all checks)
🤖 **Smart bot handling** (Renovate & Bolt fully automated)
👥 **Team-based reviews** (auto-assign by file changes)
🏷️ **Automatic labeling** (organize PRs automatically)
⚡ **Fast iteration** (merge queue with speculative checks)
📊 **Full visibility** (Mergify dashboard + GitHub insights)
🪟 **Windows support** (PowerShell scripts included)

---

**Ready to automate your workflow?** Start with [START-HERE.md](START-HERE.md)! 🚀

---

<div align="center">

**[Get Started](START-HERE.md)** • **[Windows Setup](WINDOWS-SETUP.md)** • **[TeamCity Guide](TEAMCITY-SETUP.md)** • **[Quick Reference](QUICK-REFERENCE.md)**

Made with ❤️ for teams who value automation

</div>
