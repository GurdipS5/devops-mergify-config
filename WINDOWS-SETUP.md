# Windows Setup Guide

## Running PowerShell Scripts

This package uses PowerShell (.ps1) scripts instead of bash (.sh) for Windows compatibility.

### Enable Script Execution

Before running PowerShell scripts, you may need to enable script execution:

```powershell
# Check current execution policy
Get-ExecutionPolicy

# If it shows "Restricted", change it (run PowerShell as Administrator):
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or for just this session:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### Running the Validation Script

```powershell
# Navigate to your repository
cd C:\path\to\your\repo

# Run the validation script
.\test-mergify.ps1

# Skip dependency check (if you've already verified dependencies)
.\test-mergify.ps1 -SkipDependencyCheck
```

### Installing Dependencies on Windows

#### Python Packages
```powershell
# Install pip if not already installed
python -m ensurepip --upgrade

# Install required packages
pip install yamllint mergify-cli pyyaml
```

#### Node.js Packages
```powershell
# Install Node.js from https://nodejs.org/
# Then install required packages
npm install -g js-yaml
```

### Common Windows Issues

#### Issue: "cannot be loaded because running scripts is disabled"

**Solution:**
```powershell
# Run as Administrator
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Issue: "python: command not found"

**Solutions:**
1. Install Python from https://python.org/
2. During installation, check "Add Python to PATH"
3. Or add Python to PATH manually:
   - Search "Environment Variables" in Windows
   - Edit PATH variable
   - Add Python installation directory

#### Issue: "node: command not found"

**Solutions:**
1. Install Node.js from https://nodejs.org/
2. Restart PowerShell after installation
3. Verify: `node --version`

#### Issue: Script runs but shows errors

**Solution:**
Check that all dependencies are installed:
```powershell
# Check Python
python --version

# Check pip
pip --version

# Check Node.js
node --version

# Check npm
npm --version

# Check installed packages
pip list | Select-String -Pattern "yamllint|mergify|pyyaml"
npm list -g --depth=0 | Select-String -Pattern "js-yaml"
```

### Using Git Bash on Windows

If you prefer Git Bash, you can convert PowerShell commands:

```bash
# Instead of:
.\test-mergify.ps1

# Use:
powershell -File test-mergify.ps1

# Or install the bash version tools and create your own bash script
```

### PowerShell vs Bash Syntax

| Task | Bash | PowerShell |
|------|------|------------|
| Run script | `./script.sh` | `.\script.ps1` |
| Copy file | `cp file dest` | `Copy-Item file dest` |
| Make directory | `mkdir -p dir` | `New-Item -ItemType Directory -Force dir` |
| Change directory | `cd /path` | `cd C:\path` |
| List files | `ls -la` | `Get-ChildItem` or `ls` (alias) |
| Environment var | `$HOME` | `$env:USERPROFILE` |

### Recommended Setup

1. **Install Windows Terminal** (from Microsoft Store)
   - Better PowerShell experience
   - Tabs, themes, Unicode support

2. **Install PowerShell 7+** (optional but recommended)
   - Download from: https://github.com/PowerShell/PowerShell
   - More features and better performance
   - Cross-platform compatible

3. **Use VSCode** for editing
   - Great PowerShell support
   - Built-in terminal
   - Download: https://code.visualstudio.com/

### Quick Test

Verify everything is working:

```powershell
# Test Python
python --version
pip --version

# Test Node.js
node --version
npm --version

# Test PowerShell script execution
.\test-mergify.ps1 -SkipDependencyCheck

# If all checks pass, you're ready!
```

### Git Configuration on Windows

```powershell
# Configure line endings (recommended)
git config --global core.autocrlf true

# Configure default editor
git config --global core.editor "notepad"

# Or use VS Code
git config --global core.editor "code --wait"
```

### File Paths on Windows

Remember:
- Windows uses backslashes: `C:\path\to\file`
- PowerShell accepts both: `C:\path\to\file` or `C:/path/to/file`
- Always use quotes for paths with spaces: `"C:\Program Files\file"`

### Getting Help

```powershell
# Get help for any PowerShell command
Get-Help Copy-Item
Get-Help Copy-Item -Examples

# Get detailed help for the script
Get-Help .\test-mergify.ps1 -Detailed
```

## 🎉 You're Ready!

Once you have:
- ✅ PowerShell script execution enabled
- ✅ Python and pip installed
- ✅ Node.js and npm installed
- ✅ Required packages installed (yamllint, mergify-cli, pyyaml, js-yaml)

You can run:
```powershell
.\test-mergify.ps1
```

And start using Mergify with TeamCity on Windows! 🚀
