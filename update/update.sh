#!/bin/bash
# update.sh: bring the local developer environment up to date.
#
#   update.sh [--dry-run] [--only brew,repos,tools,macos] [--greedy]
#
# Steps:
#   brew   brew update, upgrade (formulae + casks), autoremove, cleanup, doctor, Brewfile dump
#   repos  every checkout under REPO_ROOTS: fetch, rebase the current branch onto its upstream
#          with local changes stashed and put back exactly as they were (staged stays staged,
#          unstaged stays unstaged, untracked is never touched), fast-forward other branches
#   tools  whatever is installed of: mise, npm globals, gh extensions, mas, Claude Code CLI
#   macos  list pending macOS updates (never installs)
#
# Nothing is ever pushed, force-reset, deleted or committed. A repo that cannot be rebased cleanly
# is put back to exactly where it was and reported. Exit 0 = all fine, 1 = something needs you.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "$HERE/config.sh"

DRY_RUN=0
ONLY="brew,repos,tools,macos"
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --only) ONLY="$2"; shift ;;
    --greedy) BREW_GREEDY_CASKS=1 ;;
    -h|--help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 64 ;;
  esac
  shift
done

# Non-interactive: never wait on a credential prompt or an editor.
export GIT_TERMINAL_PROMPT=0 GIT_EDITOR=true HOMEBREW_NO_ENV_HINTS=1 HOMEBREW_NO_AUTO_UPDATE=1
export GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=15}"
[ -x /opt/homebrew/bin/brew ] && eval "$(/opt/homebrew/bin/brew shellenv bash)"
export PATH="$HOME/.local/bin:$PATH"

mkdir -p "$HERE/logs"
LOG="$HERE/logs/$(date +%Y-%m-%d-%H%M%S).log"
exec > >(tee -a "$LOG") 2>&1

LOCK="$HERE/logs/.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "Another update is running (remove $LOCK if it is not)."
  exit 1
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

SUMMARY=()
ATTENTION=0
ok()    { SUMMARY+=("  ok    $1"); echo "  ✓ $1"; }
skip()  { SUMMARY+=("  skip  $1"); echo "  - $1"; }
warn()  { SUMMARY+=("  WARN  $1"); echo "  ! $1"; ATTENTION=1; }
fail()  { SUMMARY+=("  FAIL  $1"); echo "  ✗ $1"; ATTENTION=1; }
has()   { command -v "$1" >/dev/null 2>&1; }
want()  { case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }
title() { echo; echo "== $1"; SUMMARY+=("$1"); }
run()   { if [ "$DRY_RUN" = 1 ]; then echo "    (dry run) $*"; else "$@"; fi; }

echo "update.sh $(date '+%Y-%m-%d %H:%M %Z')$([ "$DRY_RUN" = 1 ] && echo '  [dry run]')"

# ---------------------------------------------------------------------------------------- brew
step_brew() {
  title "Homebrew"
  has brew || { skip "brew not installed"; return; }

  brew update --quiet </dev/null || { fail "brew update failed"; return; }
  local outdated
  outdated="$(brew outdated --quiet </dev/null)"
  [ "$BREW_GREEDY_CASKS" = 1 ] && outdated="$(printf '%s\n%s' "$outdated" \
    "$(brew outdated --cask --greedy --quiet </dev/null)" | sort -u | sed '/^$/d')"

  if [ -z "$outdated" ]; then
    ok "everything current"
  else
    echo "  outdated: $(echo "$outdated" | tr '\n' ' ')"
    if run brew upgrade </dev/null; then
      [ "$BREW_GREEDY_CASKS" = 1 ] && run brew upgrade --cask --greedy </dev/null
      ok "$([ "$DRY_RUN" = 1 ] && echo 'would upgrade' || echo 'upgraded'): $(echo "$outdated" | tr '\n' ' ')"
    else
      fail "brew upgrade failed for some of: $(echo "$outdated" | tr '\n' ' ') (a cask needing sudo fails here; run brew upgrade yourself)"
    fi
  fi

  run brew autoremove --quiet </dev/null
  run brew cleanup --prune=30 --quiet </dev/null

  local doctor
  doctor="$(brew doctor 2>&1 </dev/null)"
  if [ $? -eq 0 ]; then ok "brew doctor clean"
  else warn "brew doctor: $(echo "$doctor" | grep -c '^Warning') warning(s), see log"; echo "$doctor" | sed 's/^/    /'
  fi

  if [ "$BREW_BUNDLE_DUMP" = 1 ] && [ "$DRY_RUN" = 0 ]; then
    brew bundle dump --file="$HERE/Brewfile" --force </dev/null >/dev/null 2>&1 \
      && ok "Brewfile written" || warn "brew bundle dump failed"
  fi
}

# --------------------------------------------------------------------------------------- repos
find_repos() {
  local root
  for root in "${REPO_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    find "$root" -maxdepth $((REPO_DEPTH + 1)) \( -name node_modules -o -name deps -o -name _build \) -prune \
      -o -type d -name .git -print 2>/dev/null | sed 's|/\.git$||'
  done | sort -u
}

# Fast-forward local branches other than the checked-out one when they are strictly behind their
# upstream. `git fetch . up:branch` is ff-only and refuses branches checked out in any worktree.
ff_other_branches() {
  local repo="$1" current="$2" b u moved=""
  while read -r b u; do
    [ -n "$u" ] && [ "$b" != "$current" ] || continue
    git -C "$repo" rev-parse -q --verify "$u" >/dev/null || { echo "    branch $b: upstream $u is gone"; continue; }
    [ "$(git -C "$repo" rev-parse "$b")" = "$(git -C "$repo" rev-parse "$u")" ] && continue
    git -C "$repo" merge-base --is-ancestor "$b" "$u" || continue
    if [ "$DRY_RUN" = 1 ] || git -C "$repo" fetch -q . "$u:$b" 2>/dev/null; then moved="$moved $b"; fi
  done < <(git -C "$repo" for-each-ref --format='%(refname:short) %(upstream:short)' refs/heads)
  [ -n "$moved" ] && echo "    fast-forwarded:$moved"
}

update_repo() {
  local repo="$1" name="${1/#$HOME/~}" gitdir f
  gitdir="$(git -C "$repo" rev-parse --absolute-git-dir 2>/dev/null)" || { fail "$name: not readable as a repo"; return; }
  echo "-- $name"

  for f in rebase-merge rebase-apply MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG index.lock; do
    [ -e "$gitdir/$f" ] && { warn "$name: left alone, a git operation is in progress ($f)"; return; }
  done

  if ! git -C "$repo" fetch --all --prune --quiet </dev/null; then
    fail "$name: fetch failed (network or credentials)"; return
  fi

  local branch upstream
  branch="$(git -C "$repo" symbolic-ref --quiet --short HEAD)" || { skip "$name: detached HEAD, fetched only"; return; }
  ff_other_branches "$repo" "$branch"
  upstream="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)" \
    || { skip "$name ($branch): no upstream, fetched only"; return; }

  local ahead behind
  read -r ahead behind < <(git -C "$repo" rev-list --left-right --count "HEAD...@{u}")
  if [ "$behind" -eq 0 ]; then
    ok "$name ($branch): up to date$([ "$ahead" -gt 0 ] && echo ", $ahead local commit(s) not pushed")"
    return
  fi

  local dirty=""
  [ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ] && dirty=1
  if [ "$DRY_RUN" = 1 ]; then
    ok "$name ($branch): would rebase onto $upstream (+$behind incoming, $ahead local$([ -n "$dirty" ] && echo ', local changes stashed and restored'))"
    return
  fi

  local before stash=""
  before="$(git -C "$repo" rev-parse HEAD)"
  if [ -n "$dirty" ]; then
    git -C "$repo" stash push --quiet -m "update-agent $(date '+%F %T')" \
      || { fail "$name: could not stash local changes, nothing done"; return; }
    stash="$(git -C "$repo" rev-parse 'stash@{0}')"
  fi

  local result
  if git -C "$repo" rebase --quiet </dev/null >/dev/null 2>&1; then
    result="rebased onto $upstream (+$behind incoming$([ "$ahead" -gt 0 ] && echo ", $ahead local replayed"))"
  else
    git -C "$repo" rebase --abort >/dev/null 2>&1
    result="CONFLICT"
  fi

  # Local changes that would clash with what came in: undo the rebase rather than leave conflict
  # markers. The tree is clean here (everything tracked is in the stash), so the reset loses nothing.
  if [ -n "$stash" ] && [ "$result" != CONFLICT ] \
    && ! { git -C "$repo" merge-tree --write-tree --merge-base="$stash^1" HEAD "$stash" >/dev/null 2>&1 \
        && git -C "$repo" merge-tree --write-tree --merge-base="$stash^1" HEAD "$stash^2" >/dev/null 2>&1; }; then
    git -C "$repo" reset --quiet --hard "$before"
    result="CLASH"
  fi

  if [ -n "$stash" ]; then
    if ! git -C "$repo" stash pop --index --quiet >/dev/null 2>&1; then
      # Leave the stash entry in place: it holds the changes verbatim until the user picks them back up.
      fail "$name ($branch): $([ "$result" = CONFLICT ] && echo 'rebase conflicted and was aborted; ')your local changes did not re-apply cleanly. They are safe in stash $stash (git stash list); the working tree may show conflict markers"
      return
    fi
  fi

  if [ "$result" = CONFLICT ]; then
    warn "$name ($branch): rebase onto $upstream conflicts, aborted; branch and local changes are exactly as before"
    return
  fi
  if [ "$result" = CLASH ]; then
    warn "$name ($branch): $behind incoming commit(s) touch lines you have uncommitted changes to; not rebased, everything exactly as before"
    return
  fi
  ok "$name ($branch): $result$([ -n "$stash" ] && echo ', local changes restored')"

  local changed
  changed="$(git -C "$repo" diff --name-only "$before" HEAD -- mix.lock package-lock.json yarn.lock pnpm-lock.yaml Gemfile.lock poetry.lock uv.lock .tool-versions mise.toml Brewfile 2>/dev/null | tr '\n' ' ')"
  [ -n "$changed" ] && warn "$name: dependency files changed ($changed), refresh deps when you next work here"
  [ -f "$repo/.gitmodules" ] && echo "    has submodules: not updated (git submodule update --init --recursive)"
}

step_repos() {
  title "Git repositories"
  local repo s skipped
  while read -r repo; do
    [ -n "$repo" ] || continue
    skipped=""
    for s in ${REPO_SKIP[@]+"${REPO_SKIP[@]}"}; do [ "$repo" = "$s" ] && skipped=1; done
    [ -n "$skipped" ] && { skip "${repo/#$HOME/~}: in REPO_SKIP"; continue; }
    update_repo "$repo"
  done < <(find_repos)
}

# --------------------------------------------------------------------------------------- tools
step_tools() {
  title "Other tools"
  local any=""
  if has mise; then any=1; run mise upgrade --yes </dev/null && ok "mise tools upgraded" || fail "mise upgrade failed"; fi
  if has npm;  then any=1; run npm update -g --silent </dev/null && ok "npm globals updated" || fail "npm update -g failed"; fi
  if has gh && [ -n "$(gh extension list 2>/dev/null)" ]; then
    any=1; run gh extension upgrade --all </dev/null && ok "gh extensions upgraded" || fail "gh extension upgrade failed"
  fi
  if has mas;  then any=1; run mas upgrade </dev/null && ok "App Store apps upgraded" || fail "mas upgrade failed"; fi
  if has claude; then any=1; run claude update </dev/null && ok "Claude Code CLI updated" || warn "claude update failed"; fi
  [ -n "$any" ] || skip "none of mise, npm, gh extensions, mas, claude CLI present"
}

# --------------------------------------------------------------------------------------- macos
step_macos() {
  title "macOS"
  [ "$CHECK_MACOS" = 1 ] || { skip "disabled in config"; return; }
  local list
  list="$(softwareupdate --list 2>&1 </dev/null)"
  if echo "$list" | grep -q '^\* Label:'; then
    warn "macOS updates pending (install from System Settings): $(echo "$list" | sed -n 's/^\* Label: //p' | paste -sd ',' - | sed 's/,/, /g')"
  else
    ok "no macOS updates pending"
  fi
}

want brew  && step_brew
want repos && step_repos
want tools && step_tools
want macos && step_macos

echo
echo "================ summary"
printf '%s\n' "${SUMMARY[@]}"
echo "log: $LOG"
# A full real run counts as this week's run for scheduled.sh.
[ "$DRY_RUN" = 0 ] && [ "$ONLY" = "brew,repos,tools,macos" ] && date +%s > "$HERE/logs/.last-run"
ls -1t "$HERE/logs"/*.log 2>/dev/null | tail -n +31 | xargs rm -f 2>/dev/null
exit $ATTENTION
