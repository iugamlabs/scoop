# iugamlabs Scoop bucket

Scoop bucket for iugamlabs and related tools.

## Install

```powershell
scoop bucket add iugamlabs https://github.com/iugamlabs/scoop
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
| [ship](bucket/ship.json) | [heyoungai/ship](https://github.com/heyoungai/ship) | Docker / binary release CLI |
| [code-porter](bucket/code-porter.json) | [star-plan/code-porter](https://github.com/star-plan/code-porter) | Local code archive import/export; requires Git |
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
