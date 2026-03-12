# claude-container Justfile — Windows/WSL2 edition
# Docker Desktop replaces Colima. Run all commands from inside WSL2.
#
# Usage:
#   just setup              # verify Docker Desktop is reachable from WSL2
#   just build              # build the container image
#   just create <n>         # create a project container
#   just login <n>          # authenticate with Claude subscription
#   just claude <n>         # start Claude in YOLO mode
#   just claude-safe <n>    # start Claude with permission prompts
#   just shell <n>          # open a bash shell in the container
#   just list               # list all claude containers
#   just start/stop/restart <n>
#   just destroy <n>        # remove container (project files kept)
#   just logs <n>           # show container logs
#   just stats              # resource usage for all containers

# ── configuration ────────────────────────────────────────────────────────────

image := "claude-container"
projects_dir := justfile_directory() + "/projects"

# Load ANTHROPIC_API_KEY from .env if present
set dotenv-load

# ── setup (replaces Colima — just checks Docker Desktop is running) ───────────

# Verify Docker Desktop is reachable from WSL2
setup:
    @echo "Checking Docker Desktop is running and accessible from WSL2..."
    @docker info > /dev/null 2>&1 || { \
        echo ""; \
        echo "ERROR: Cannot connect to Docker."; \
        echo ""; \
        echo "Make sure Docker Desktop is running on Windows and WSL2"; \
        echo "integration is enabled:"; \
        echo "  Docker Desktop → Settings → Resources → WSL Integration"; \
        echo "  → Enable integration with your Ubuntu distro → Apply & Restart"; \
        echo ""; \
        exit 1; \
    }
    @echo "Docker is running."
    @docker version --format 'Client: {{{{.Client.Version}}}}  Server: {{{{.Server.Version}}}}'
    @echo ""
    @echo "Setup complete. Run 'just build' to build the container image."

# ── image ────────────────────────────────────────────────────────────────────

# Build the container image
build:
    docker build -t {{image}} .

# Rebuild without cache (useful after changing Dockerfile or config)
rebuild:
    docker build --no-cache -t {{image}} .

# ── project lifecycle ────────────────────────────────────────────────────────

# Create a new project container with a bind-mounted workspace
# Pass extra Docker options after --  e.g.: just create my-project -- -p 8080:8080
create name +args="":
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p "{{projects_dir}}/{{name}}"
    docker_args=(
        --name "claude-{{name}}"
        --hostname "claude-{{name}}"
        --detach
        --restart unless-stopped
        -v "{{projects_dir}}/{{name}}:/workspace"
        -v "{{justfile_directory()}}/config/CLAUDE.md:/root/.claude/CLAUDE.md:ro"
        -v "{{justfile_directory()}}/config/claude-settings.json:/root/.claude/settings.json:ro"
    )
    if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
        docker_args+=(-e "ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}")
    fi
    docker_args+=({{args}})
    docker_args+=("{{image}}" sleep infinity)
    docker create "${docker_args[@]}"
    docker start "claude-{{name}}"
    echo ""
    echo "Container 'claude-{{name}}' created and started."
    echo "Project folder: {{projects_dir}}/{{name}}"
    echo ""
    echo "Next steps:"
    echo "  Subscription users:  just login {{name}}"
    echo "  API key users:       you are already authenticated via .env"
    echo "  Start Claude:        just claude {{name}}"

# Start a stopped container
start name:
    docker start "claude-{{name}}"

# Stop a running container
stop name:
    docker stop "claude-{{name}}"

# Restart a container
restart name:
    docker restart "claude-{{name}}"

# Remove a container entirely (project files in projects/<n>/ are NOT deleted)
destroy name:
    @echo "Removing container claude-{{name}} (project files kept)..."
    docker rm -f "claude-{{name}}" 2>/dev/null || true
    @echo "Done. Project files still at: {{projects_dir}}/{{name}}"

# ── claude ───────────────────────────────────────────────────────────────────

# Authenticate with a Claude Pro/Max subscription (run once per container)
login name:
    @_ensure_running {{name}}
    docker exec -it "claude-{{name}}" claude login

# Run Claude in YOLO mode — no permission prompts (safe inside container)
# Optionally pass a prompt: just claude my-project "summarise /workspace/data.csv"
claude name prompt="":
    @_ensure_running {{name}}
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{prompt}}" ]; then
        docker exec -it "claude-{{name}}" \
            claude --dangerously-skip-permissions -p "{{prompt}}"
    else
        docker exec -it "claude-{{name}}" \
            claude --dangerously-skip-permissions
    fi

# Run Claude with permission prompts (asks before each file/command operation)
claude-safe name prompt="":
    @_ensure_running {{name}}
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "{{prompt}}" ]; then
        docker exec -it "claude-{{name}}" claude -p "{{prompt}}"
    else
        docker exec -it "claude-{{name}}" claude
    fi

# ── shell & files ────────────────────────────────────────────────────────────

# Open an interactive bash shell inside the container
shell name:
    @_ensure_running {{name}}
    docker exec -it "claude-{{name}}" bash

# Copy a file or folder from WSL2/Windows into the container's workspace
# Example: just cp-to my-project ./data /workspace/data
cp-to name src dest:
    docker cp "{{src}}" "claude-{{name}}:{{dest}}"

# Copy a file or folder from the container back to WSL2
# Example: just cp-from my-project /workspace/output.csv ./output.csv
cp-from name src dest:
    docker cp "claude-{{name}}:{{src}}" "{{dest}}"

# ── monitoring ───────────────────────────────────────────────────────────────

# List all claude containers with their status
list:
    @docker ps -a \
        --filter "name=claude-" \
        --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}" \
        | sed 's/claude-//g'

# Show logs for a container
logs name:
    docker logs "claude-{{name}}"

# Show live resource usage for all running claude containers
stats:
    docker stats $(docker ps --filter "name=claude-" --format "{{.Names}}" | tr '\n' ' ')

# ── internal helpers ─────────────────────────────────────────────────────────

# Ensure container is running, start it if stopped
_ensure_running name:
    #!/usr/bin/env bash
    set -euo pipefail
    status=$(docker inspect -f '{{.State.Status}}' "claude-{{name}}" 2>/dev/null || echo "missing")
    if [ "$status" = "missing" ]; then
        echo "ERROR: Container 'claude-{{name}}' does not exist."
        echo "Run: just create {{name}}"
        exit 1
    elif [ "$status" = "exited" ] || [ "$status" = "created" ]; then
        echo "Container 'claude-{{name}}' is stopped — starting it..."
        docker start "claude-{{name}}"
        sleep 1
    fi
