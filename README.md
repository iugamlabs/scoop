# iugam Scoop bucket

Scoop bucket for iugam and related tools.

## Install

```powershell
scoop bucket add iugam https://github.com/iugamlabs/scoop
scoop install ship
scoop install code-porter
scoop install starblog-publisher
```

Update apps:

```powershell
scoop update ship
scoop update code-porter
```

## Apps

| App | Source | Notes |
|-----|--------|--------|
| [ship](bucket/ship.json) | [iugamlabs/ship](https://github.com/iugamlabs/ship) | Docker / binary release CLI |
| [code-porter](bucket/code-porter.json) | [iugamlabs/code-porter](https://github.com/iugamlabs/code-porter) | Local code archive import/export; requires Git |
| `starblog-publisher` | [star-blog/starblog-publisher](https://github.com/star-blog/starblog-publisher) | Desktop GUI; Native AOT (default) |
| `starblog-publisher-framework-dependent` | [star-blog/starblog-publisher](https://github.com/star-blog/starblog-publisher) | Desktop GUI; requires .NET 10 Runtime |
| `starblog-publisher-self-contained` | [star-blog/starblog-publisher](https://github.com/star-blog/starblog-publisher) | Desktop GUI; self-contained, non-AOT |

## How versions stay current

Manifests are updated by GitHub Actions in this repository (schedule + manual dispatch), reading the latest GitHub Release assets and checksum files from each app repo.

App repositories no longer commit Scoop manifests into their own history.

## Manual sync

```text
Actions → Sync manifests → Run workflow
```

Or wait for the scheduled run (every 4 hours).

## 已有用户 / Existing users

无需卸载应用。旧源名称可保留，只更新 Git remote；避免添加重复源。

Keep installed applications and the existing source name; update its Git remote instead of adding a duplicate source.

[迁移说明 / Migration instructions](https://github.com/iugamlabs/.github/blob/master/docs/migration.md)
