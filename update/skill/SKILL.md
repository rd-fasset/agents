---
name: update
description: Rikesh's update agent. Use for "/update", "update my machine", "update brew", "pull my repos", or "is my dev environment up to date". Runs /Users/rikesh/scripts/agents/update/update.sh and resolves what it could not.
---

# Update agent

Keeps the local developer environment current: Homebrew, every git checkout under the roots in
`/Users/rikesh/scripts/agents/update/config.sh`, other installed tool managers, and a macOS update check.

## Run

1. Run `/Users/rikesh/scripts/agents/update/update.sh` with Bash, in the background (brew can take
   several minutes). Pass flags the user asked for:
   - `--dry-run` for "what would update" or "check"
   - `--only brew` / `--only repos` / `--only tools,macos` to limit the steps
   - `--greedy` to also upgrade self-updating casks; warn the user first that it can quit running apps
2. Read the summary block at the end of the output. Exit 0 means everything is fine; 1 means at least
   one `WARN` or `FAIL` line needs a human.
3. Reply with: what was upgraded (one line), what was rebased (one line per repo that moved),
   then each WARN/FAIL with what it means and the next step. Keep it short when everything is fine.

## Following up on a WARN / FAIL

- **Rebase conflicts (repo left as it was):** offer to do the rebase with the user. Only after they
  say yes: stash, `git rebase`, resolve the conflicts with them, `git stash pop --index`. Never
  `git rebase --skip`, never resolve by taking one side wholesale without asking.
- **Local changes did not re-apply (stash kept):** the stash sha is in the message. Show
  `git stash show -p <sha>` and help them re-apply. Never `git stash drop` or `clear`.
- **Operation in progress / detached HEAD / no upstream:** report it; don't fix it unasked.
- **Dependency files changed:** suggest the refresh command (`mix deps.get`, `npm install`, …).
- **brew upgrade failed:** usually a cask needing sudo. Tell the user to run `brew upgrade <name>`
  in a terminal; you cannot enter their password.
- **macOS updates pending:** report only. Never run `softwareupdate --install`.

## Never

Push, force-reset, delete branches or stashes, commit, or edit repos outside a rebase the user asked
for. Never touch the repos the script skips.

## Schedule

A launchd job (`com.rikesh.update-agent`) runs `scheduled.sh` every Monday at 10:00 and at login, and once
a week at most. For "when does it next run" or "did it run", use `scheduled.sh --check`, the newest
file in `logs/` and `logs/launchd.log`. To change the schedule, edit `install-schedule.sh` and re-run
it, and update the due-time calculation in `scheduled.sh` to match.

## Changing behaviour

Settings (repo roots, skips, greedy casks, Brewfile dump, macOS check) live in `config.sh`. Edit
that rather than the script when the user asks to add a folder or skip a repo.
