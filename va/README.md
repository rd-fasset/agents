# va: Rikesh's virtual assistant

This is a Claude Code assistant. It triages Slack, Gmail, Google Calendar, Jira and GitHub into a
private dashboard, drafts replies for approval, and auto-accepts meetings that pass the rules
in `profile.md`.

| File | What it is | Where Claude reads it from |
|---|---|---|
| `profile.md` | People, working hours, priorities, autonomy and meeting rules. Edit this to change behaviour. | Read directly by the two below |
| `scheduled-task/SKILL.md` | The 30-minute check: gather, act, write the dashboard | `~/.claude/scheduled-tasks/va-check/SKILL.md` (copy, by `install.sh`) |
| `skill/SKILL.md` | The `/va` command: catch-up, scheduling, rule changes | `~/.claude/skills/va` (symlink to `skill/`) |
| `install.sh` | Copies `scheduled-task/SKILL.md` into `~/.claude`. Git hooks run it after every commit, pull and branch switch. | Run by hand or by `../githooks` |
| `dashboard.html` | Source of the dashboard page | Published at https://claude.ai/artifact/B41zYcuPDj9HM4C64A9jEa |

## Setting it up on a new machine

```bash
git clone <this repo> ~/scripts/agents
```

Create the scheduled task in the Claude app first (Scheduled → new task with id `va-check`,
cron `*/30 6-22 * * 1-5`). Then link the skill, install the task prompt and turn on the git hooks:

```bash
ln -s ~/scripts/agents/va/skill ~/.claude/skills/va
bash ~/scripts/agents/va/install.sh --hooks
```

The app only reads the scheduled task's prompt from `~/.claude/scheduled-tasks/va-check/SKILL.md`, and
refuses to open it if it's a symlink (the task then fails every run without saying so). That's why
`install.sh` copies it. The skill can stay a symlink. With the hooks on, committing or pulling a
prompt change updates the installed copy; without them, run `install.sh` after each change.

## Notes

- If you edit the task's prompt in the app, the app writes over the installed copy, and your next commit
  or pull puts the repo version back. Make prompt changes in `scheduled-task/SKILL.md`.
- To republish the dashboard after editing `dashboard.html`, ask Claude to publish it **to the
  existing URL** above. Publishing without that URL creates a new page with an empty database.
- The dashboard's items live in the artifact's database, not in this repo.
- `profile.md` names colleagues and internal systems. Keep the repo private.
