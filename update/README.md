# update: keeps the local dev environment current

| File | What it is |
|---|---|
| `update.sh` | Does the work. Safe to run by hand: `./update.sh --dry-run` first if unsure. |
| `config.sh` | Repo roots, repos to skip, greedy casks, Brewfile dump, macOS check. |
| `skill/SKILL.md` | The `/update` command, read from `~/.claude/skills/update` (symlink to `skill/`). |
| `Brewfile` | Written after each run (`brew bundle dump`). `brew bundle --file=Brewfile` rebuilds a machine. |
| `logs/` | One log per run, last 30 kept. Not committed. |

## What a run does

1. **Homebrew:** `update`, `upgrade` (formulae and casks; `--greedy` adds self-updating casks),
   `autoremove`, `cleanup --prune=30`, `doctor` (report only), Brewfile dump.
2. **Git repos** (each directory with a real `.git/` under `REPO_ROOTS`; worktrees and submodules skipped):
   - `fetch --all --prune`
   - if the current branch is behind its upstream: stash tracked changes, `git rebase` onto the
     upstream, `git stash pop --index`. Staged stays staged, unstaged stays unstaged, untracked is untouched.
   - on conflict: `rebase --abort` and restore the stash, so the repo is exactly as it was. Then it's reported.
   - other local branches strictly behind their upstream are fast-forwarded. Diverged ones are left alone.
   - repos mid-rebase/merge, detached, or without an upstream are only fetched.
   - flags changed lockfiles (`mix.lock`, `package-lock.json`, …) so you know to refresh deps.
3. **Other tools, if installed:** `mise upgrade`, `npm update -g`, `gh extension upgrade --all`,
   `mas upgrade`, `claude update`.
4. **macOS:** lists pending updates; never installs.

It never pushes, resets, deletes or commits. Exit code 1 means something needs you.

## Setting it up on a new machine

```bash
ln -s ~/scripts/agents/update/skill ~/.claude/skills/update
```
