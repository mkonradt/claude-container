# claude-container (Windows/WSL2 edition)

Isolated Docker containers for running [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in YOLO mode (`--dangerously-skip-permissions`) without affecting your host machine.

Project files are bind-mounted so they persist on the host. Containers are long-lived (stop/start). Everything is managed through a Justfile.

> This is a Windows/WSL2 adaptation of [paulgp/claude-container](https://github.com/paulgp/claude-container).
> Colima is replaced by Docker Desktop with WSL2 backend. All `just` commands are run from inside WSL2.

## Prerequisites

- Windows 10 (2004+) or Windows 11 with WSL2 installed
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) with WSL2 backend enabled
- [just](https://github.com/casey/just) installed inside WSL2
- A [Claude Pro or Max subscription](https://claude.ai), **or** an [Anthropic API key](https://console.anthropic.com/)

See [docs/getting-started.md](docs/getting-started.md) for full setup instructions.

## Quick Start

```bash
# 1. Verify Docker Desktop is reachable from WSL2
just setup

# 2. Build the image
just build

# 3. Create a project
just create my-project

# 4a. Subscription users: log in once per container
just login my-project

# 4b. API key users: set your key
cp .env.example .env
# Edit .env with your ANTHROPIC_API_KEY, then recreate the container

# 5. Start Claude
just claude my-project
```

## Tools Inside the Container

`git`, `python3`, `uv`, `Node.js 22`, `R`, `DuckDB`, `just`, `build-essential`, `Claude Code CLI`

## Recipes

| Recipe | Purpose |
| --- | --- |
| `just setup` | Verify Docker Desktop is running and accessible from WSL2 |
| `just build` | Build the container image |
| `just rebuild` | Build without cache |
| `just create <n> [-- DOCKER_ARGS]` | Create container with bind-mounted project dir |
| `just start/stop/restart <n>` | Container lifecycle |
| `just login <n>` | Log in with Claude subscription (once per container) |
| `just shell <n>` | Open a bash shell (auto-starts if stopped) |
| `just claude <n> [prompt]` | Run Claude in YOLO mode (auto-starts) |
| `just claude-safe <n> [prompt]` | Run Claude with permission prompts |
| `just cp-to <n> <src> <dest>` | Copy files from WSL2 into container |
| `just cp-from <n> <src> <dest>` | Copy files from container back out |
| `just destroy <n>` | Remove container (project files kept) |
| `just list` | Show all claude containers |
| `just logs <n>` | Show container logs |
| `just stats` | Resource usage for all containers |

## Extra Docker Options

Pass additional mounts, ports, or env vars when creating a container:

```bash
just create my-project -- -p 8080:8080 -e SECRET=val --mount type=bind,src=/data,dst=/data
```

## Accessing Project Files from Windows

Project files live inside WSL2 at `~/claude-container/projects/<name>/`.
Access them from Windows Explorer at:

```
\\wsl$\Ubuntu\home\<your-username>\claude-container\projects\
```

## How It Works

- **Docker Desktop** (WSL2 backend) provides the container runtime — no Colima needed on Windows
- Containers run `sleep infinity` and you `exec` into them
- `/workspace` inside the container is bind-mounted to `projects/<n>/` on the WSL2 filesystem
- **Subscription auth:** `just login <n>` runs `claude login` inside the container (once per container)
- **API key auth:** the key flows from `.env` → just → `docker create -e ANTHROPIC_API_KEY`
- `just destroy` removes the container but project files stay in `projects/`

## Customising Claude's Behaviour

Edit these files, then run `just rebuild` to apply to all future containers:

- `config/CLAUDE.md` — standing instructions Claude reads at session start
- `config/claude-settings.json` — permission settings and behaviour flags
