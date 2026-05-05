The dotfiles openclaw instance is a singleton — exactly one containerized instance runs at any time. Self-modification is allowed (the agent can work on its own repo). No self-replication: spawning multiple dotfiles instances would cause context explosion and conflicting memory writes.

Per-project agents (Issue Agents) spawn freely — one per GitHub issue — because each is isolated to its project directory with no egress.
