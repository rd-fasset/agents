# Settings for update.sh. Sourced as bash; edit freely.

# Directories searched (up to REPO_DEPTH levels down) for git checkouts to update.
# Linked worktrees and submodules are never touched: only directories holding a real .git/.
REPO_ROOTS=(
  "$HOME/development"
  "$HOME/scripts"
  "$HOME/Documents/fasset-ASH"
  "$HOME/Documents/fasset projects"
)
REPO_DEPTH=3

# Checkouts to leave alone entirely (absolute paths).
REPO_SKIP=()

# 1 = also upgrade casks that update themselves (Chrome, Slack, …). This can quit a running app.
BREW_GREEDY_CASKS=0

# 1 = write a Brewfile next to this script after upgrading, as a record for rebuilding the machine.
BREW_BUNDLE_DUMP=1

# 1 = list pending macOS updates (never installs them).
CHECK_MACOS=1
