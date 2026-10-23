# va: Rikesh's virtual assistant

This is a Claude Code assistant. It triages Slack, Gmail, Google Calendar, Jira and GitHub into a
private dashboard, drafts replies for approval, and auto-accepts meetings that pass the rules
in `profile.md`.

| File | What it is | Where Claude reads it from |
|---|---|---|
| `profile.md` | People, working hours, priorities, autonomy and meeting rules. Edit this to change behaviour. | Read directly by the two below |
| `scheduled-task/SKILL.md` | The 30-minute check: gather, act, write the dashboard | `~/.claude/scheduled-tasks/va-check/SKILL.md` (symlink) |
| `skill/SKILL.md` | The `/va` command: catch-up, scheduling, rule changes | `~/.claude/skills/va` (symlink to `skill/`) |
| `dashboard.html` | Source of the dashboard page | Published at https://claude.ai/artifact/B41zYcuPDj9HM4C64A9jEa |

## Setting it up on a new machine

```bash
git clone <this repo> ~/scripts/agents/va
ln -s ~/scripts/agents/va/skill ~/.claude/skills/va
```

The scheduled task has to be created in the Claude app first (Scheduled → new task with id `va-check`,
cron `*/30 6-22 * * 1-5`). After that, replace its `SKILL.md` with a symlink to `scheduled-task/SKILL.md`.

## Notes

- If you edit the schedule in the app, the app may write a plain file over the symlink. Check with
  `ls -l ~/.claude/scheduled-tasks/va-check/` afterwards.
- To republish the dashboard after editing `dashboard.html`, ask Claude to publish it **to the
  existing URL** above. Publishing without that URL creates a new page with an empty database.
- The dashboard's items live in the artifact's database, not in this repo.
- `profile.md` names colleagues and internal systems. Keep the repo private.
