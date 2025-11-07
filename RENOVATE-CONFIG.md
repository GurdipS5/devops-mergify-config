# Renovate & Bolt Integration Guide

This guide explains how Mergify is configured to work with Renovate and Bolt for automated dependency management.

## 🤖 Overview

Your Mergify configuration includes smart automation for both Renovate and Bolt, with different rules based on the type of update.

## 📊 Update Type Handling

### Patch Updates (e.g., 1.2.3 → 1.2.4)
- ✅ **Auto-approved** - No manual review needed
- ✅ **Auto-merged** - Merged automatically if CI passes
- 🏷️ Labeled: `dependencies`, `patch-update`
- ⚡ Fastest path to production

**Why?** Patch updates typically contain bug fixes and security patches with minimal breaking change risk.

### Minor Updates (e.g., 1.2.3 → 1.3.0)
- 👤 **Requires 1 approval** - Manual review needed
- ✅ **Auto-merged after approval** - If CI passes
- 🏷️ Labeled: `dependencies`, `minor-update`
- ⏱️ Standard merge flow

**Why?** Minor updates may include new features that need review but are backward compatible.

### Major Updates (e.g., 1.2.3 → 2.0.0)
- 👥 **Requires 1 approval** - Manual review needed
- 🚨 **Labeled as major** - Extra visibility
- 🏷️ Labeled: `dependencies`, `major-update`
- 📋 May need additional testing

**Why?** Major updates can include breaking changes requiring careful review and testing.

## 🔧 Configuration Details

### Renovate Rules

#### Rule 1: Standard Renovate Auto-Merge
```yaml
- name: Automatic merge for Renovate pull requests
  conditions:
    - author=renovate[bot]
    - check-success=ci-tests
    - check-success=lint
    - check-success=mergify-validation
    - "#approved-reviews-by>=1"
    - "#changes-requested-reviews-by=0"
  actions:
    queue:
      name: default
      method: squash
```

**Applies to:** All Renovate PRs that have 1 approval and passing CI.

#### Rule 2: Patch Update Auto-Approval
```yaml
- name: Auto-merge Renovate patch updates
  conditions:
    - author=renovate[bot]
    - title~=^(fix\(deps\)|chore\(deps\)).*\[SECURITY\]|^Update dependency.*to v.*\.\d+\.\d+$
    - check-success=ci-tests
    - check-success=lint
    - check-success=mergify-validation
    - "#changes-requested-reviews-by=0"
    - -label~=major-update
  actions:
    queue:
      name: default
      method: squash
    review:
      type: APPROVE
```

**Applies to:** Patch-level updates and security fixes. Auto-approved without human review.

#### Rule 3-5: Automatic Labeling
Automatically adds labels based on the version change detected in the PR title:
- `major-update` for x.0.0 updates
- `minor-update` for 0.x.0 updates
- `patch-update` for 0.0.x updates

### Bolt Rules

```yaml
- name: Automatic merge for Bolt pull requests
  conditions:
    - author=bolt[bot]
    - check-success=ci-tests
    - check-success=lint
    - check-success=mergify-validation
    - "#approved-reviews-by>=1"
    - "#changes-requested-reviews-by=0"
  actions:
    queue:
      name: default
      method: squash
```

**Applies to:** All Bolt PRs with 1 approval and passing CI.

## 🎯 Workflow Examples

### Example 1: Patch Security Update
```
1. Renovate creates PR: "fix(deps): update lodash to v4.17.22 [SECURITY]"
2. CI runs automatically (tests + lint)
3. Mergify auto-approves ✅
4. Mergify adds labels: dependencies, patch-update
5. CI passes ✅
6. Mergify auto-merges 🎉
7. Branch deleted automatically
```
**Total time: ~5 minutes** (CI duration only)

### Example 2: Minor Update
```
1. Renovate creates PR: "chore(deps): update react to v18.3.0"
2. CI runs automatically (tests + lint)
3. Mergify adds labels: dependencies, minor-update
4. Developer reviews and approves 👤
5. CI passes ✅
6. Mergify auto-merges 🎉
7. Branch deleted automatically
```
**Total time: ~5 minutes + review time**

### Example 3: Major Update
```
1. Renovate creates PR: "chore(deps): update next to v15.0.0"
2. CI runs automatically (tests + lint)
3. Mergify adds labels: dependencies, major-update 🚨
4. Team discusses potential breaking changes
5. Developer approves after review 👤
6. CI passes ✅
7. Mergify auto-merges 🎉
8. Branch deleted automatically
```
**Total time: Variable based on review complexity**

## 🔒 Safety Features

### All Updates Must Pass:
1. ✅ All CI checks (tests, lint, type-check, build)
2. ✅ Mergify validation check
3. ✅ No changes requested by reviewers
4. ✅ Not labeled `do-not-merge` or `work-in-progress`

### Additional Protections:
- Stale reviews dismissed on new commits
- Linear history required (no merge commits)
- Auto-deletion of merged branches
- Security updates prioritized in title matching

## ⚙️ Customization Options

### Change Approval Requirements

**Require 2 approvals for major updates:**
```yaml
- name: Require 2 approvals for major Renovate updates
  conditions:
    - author=renovate[bot]
    - label=major-update
    - "#approved-reviews-by>=2"
    - "#changes-requested-reviews-by=0"
    - check-success=ci-tests
    - check-success=lint
  actions:
    queue:
      name: default
```

### Disable Auto-Merge for Certain Packages

**Block auto-merge for critical packages:**
```yaml
- name: Require manual merge for critical packages
  conditions:
    - author=renovate[bot]
    - body~=(react|next|express|database)
  actions:
    label:
      add:
        - requires-manual-merge
    comment:
      message: "⚠️ Critical package update - requires manual merge"
```

### Custom Notification for Major Updates

**Ping specific team for major updates:**
```yaml
- name: Notify team of major updates
  conditions:
    - author=renovate[bot]
    - label=major-update
  actions:
    comment:
      message: "@backend-team Major dependency update requires review"
```

## 📈 Monitoring

### View Renovate Activity
```bash
# See all Renovate PRs
gh pr list --author renovate[bot]

# See pending approvals
gh pr list --author renovate[bot] --label minor-update --json number,title,reviews
```

### Check Merge Queue Status
Visit the Mergify dashboard:
```
https://dashboard.mergify.com/github/<org>/<repo>/queues
```

### Review Auto-Merge History
```bash
# See recently merged Renovate PRs
gh pr list --state merged --author renovate[bot] --limit 20
```

## 🐛 Troubleshooting

### Issue: Patch updates not auto-merging
**Cause:** Title regex might not match your Renovate config.

**Solution:** Check your Renovate title format and update the regex:
```yaml
- title~=^Update dependency.*to v.*\.\d+\.\d+$
```

### Issue: Wrong labels applied
**Cause:** Renovate title format doesn't include version numbers.

**Solution:** Update Renovate config to include semantic version in titles:
```json
{
  "separateMinorPatch": true,
  "commitMessageSuffix": "to {{newVersion}}"
}
```

### Issue: Bot PRs stuck in queue
**Cause:** CI checks not matching Mergify conditions.

**Solution:** Verify check names match:
```bash
# List actual check names
gh pr view <PR_NUMBER> --json statusCheckRollup --jq '.statusCheckRollup[].name'
```

## 🔄 Renovate Configuration Tips

### Recommended Renovate Config
```json
{
  "extends": ["config:base"],
  "separateMinorPatch": true,
  "separateMajorMinor": true,
  "labels": ["dependencies"],
  "assignAutomerge": false,
  "ignoreDeps": [],
  "packageRules": [
    {
      "matchUpdateTypes": ["patch"],
      "automerge": false,
      "labels": ["dependencies", "patch-update"]
    },
    {
      "matchUpdateTypes": ["minor"],
      "labels": ["dependencies", "minor-update"]
    },
    {
      "matchUpdateTypes": ["major"],
      "labels": ["dependencies", "major-update"]
    }
  ]
}
```

**Note:** Let Mergify handle the actual auto-merge, not Renovate, for better control and visibility.

## 📚 Best Practices

1. **Review the queue regularly** - Check dashboard weekly
2. **Monitor major updates closely** - May need additional testing
3. **Keep CI fast** - Faster CI = faster merges
4. **Group related updates** - Configure Renovate to group related packages
5. **Test in staging first** - For critical dependencies
6. **Set up alerts** - Get notified of merge failures

## 🚀 Advanced Configuration

### Schedule Renovate Merges
```yaml
- name: Only auto-merge during business hours
  conditions:
    - author=renovate[bot]
    - schedule=Mon-Fri 09:00-17:00[America/New_York]
  actions:
    queue:
      name: default
```

### Priority Lane for Security Updates
```yaml
queue_rules:
  - name: security-priority
    conditions:
      - check-success=ci-tests
      - check-success=lint
      - label=security
    priority: high
    speculative_checks: 5
```

## 📞 Support

- **Renovate Docs**: https://docs.renovatebot.com/
- **Bolt Docs**: [Check your Mend documentation]
- **Mergify Docs**: https://docs.mergify.com/
- **This Config**: See main README.md

---

**Pro Tip:** Start with conservative settings and gradually relax constraints as you build confidence in your test suite!
