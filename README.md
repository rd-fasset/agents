Somewhere for my agents to sleep

- `va/`: virtual assistant (see `va/README.md`).
- `rikeshs-dev-env/`: weekly machine update agent (see `rikeshs-dev-env/README.md`).
- `githooks/`: after a commit, pull or branch switch, re-installs the VA's scheduled-task prompt.
  Turn on with `bash va/install.sh --hooks` (sets `core.hooksPath=githooks`).
