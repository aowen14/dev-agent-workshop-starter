# Dev Agent Workshop Starter

A product inventory tracker built with FastAPI and React — designed as a workshop starter for learning Claude Code.

## Quick Start

```bash
# Clone and setup
git clone https://github.com/aowen14/dev-agent-workshop-starter.git
cd dev-agent-workshop-starter
./setup.sh

# Run the app
./scripts/run-dev.sh
```

Backend runs on http://localhost:8000, frontend on http://localhost:5173.

## What's Inside

- **Full-stack app**: FastAPI backend + React frontend with Tailwind CSS
- **28 seed products** across 4 categories with computed stock statuses
- **REST API** with CRUD, filtering, search, and stats
- **24 passing tests** covering all endpoints
- **Claude Code config**: pre-built agent, hooks, and an empty skills directory for you to fill

## Project Structure

```
├── src/                    # FastAPI backend
│   ├── main.py             # App + endpoints
│   ├── models.py           # Pydantic models
│   ├── database.py         # In-memory store
│   └── seed_data.py        # 28 seed products
├── tests/                  # pytest test suite
├── frontend/               # React + Vite + Tailwind
│   └── src/
│       ├── App.tsx          # Main app component
│       ├── api/client.ts    # API client
│       └── components/      # UI components
├── .claude/
│   ├── agents/             # Custom agents (code-reviewer included)
│   ├── skills/             # Your skills go here!
│   └── settings.json       # Hooks and permissions
├── scripts/                # Dev scripts
├── CLAUDE.md               # Project conventions for Claude
└── setup.sh                # One-command setup
```

## Workshop Exercises

**[See WORKSHOP.md for the full hands-on guide.](WORKSHOP.md)**

The exercises walk you through:
1. Exploring the codebase with subagents
2. Using the pre-built code-reviewer agent
3. Building a `/check-ui` skill from scratch — make API changes and verify them
4. Seeing auto-formatting hooks in action
5. Building your own agents and skills

Start Claude Code in this directory:

```bash
claude
```

Claude reads CLAUDE.md and understands the project. The `.claude/skills/` directory is intentionally empty — building skills is the exercise.

## The Sandbox Demo (`/.sandbox` + `/demo`)

This repo doubles as the live demo for the **Sandboxes for Agents** talk at the LA Claude Code Meetup. On top of the workshop track above, there's a second track: hand Claude Code an isolated docker-compose stack and watch it autonomously add real Postgres persistence to the in-memory app.

```bash
./demo/00-prewarm.sh        # warm the workspace image once before the talk
./demo/40-good-path.sh      # full lifecycle: spin up → Claude works → tear down
```

Full step-by-step: see [`demo/RUNBOOK.md`](demo/RUNBOOK.md).
Agent / engineer context for that folder: see [`demo/README.md`](demo/README.md).

### One thing worth being honest about

The demo argues a thesis — *agents inherit the environment you give them; the team with the best DevOps wins; sandboxes are also where you enforce policy* — and then bootstraps that argument with a bash script that spins the sandbox up, snapshots state, runs Claude inside, captures the artifact, and tears the sandbox down.

The **outer sandbox boundary** has to be created by something other than Claude — that's bootstrap, not a thesis violation. But **everything happening inside the sandbox** (the Postgres lifecycle, the before/after snapshots, the migration verification) is in principle work that Claude itself should orchestrate. In the current demo, the bash script does it.

The next iteration of this demo strips Postgres-the-service out of `docker-compose.yml`, bakes Postgres into the workspace image, and lets Claude start/stop/migrate it itself — so the agent transcript contains the whole environmental lifecycle and the bash shrinks to "boot workspace, run Claude, tear workspace down."

For tonight's talk: the script handles the inner work. We acknowledge it. The structure of the demo still makes the boundary tangible (the audience watches the sandbox come into existence and disappear), and the captured trajectory still tells the story.

## License

MIT
