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

# ── configuration ─────────────────────────────────────────────────────────────

image := "claude-container"
projects_dir := justfile_directory() + "/projects"

set dotenv-load

# ── setup ─────────────────────────────────────────────────────────────────────

setup:
	@echo "Checking Docker Desktop is running and accessible from WSL2..."
	@docker info > /dev/null 2>&1 || (echo "" && echo "ERROR: Cannot connect to Docker." && echo "" && echo "Make sure Docker Desktop is running on Windows and WSL2 integration is enabled:" && echo "  Docker Desktop -> Settings -> Resources -> WSL Integration" && echo "  -> Enable integration with your Ubuntu distro -> Apply & Restart" && echo "" && exit 1)
	@echo "Docker is running."
	@echo ""
	@echo "Setup complete. Run 'just build' to build the container image."

# ── image ──────────────────────────────────────────────────────────────────────

build:
	docker build -t {{image}} .

rebuild:
	docker build --no-cache -t {{image}} .

# ── project lifecycle ──────────────────────────────────────────────────────────

create name +args="":
	#!/usr/bin/env bash
	set -euo pipefail
	mkdir -p "{{projects_dir}}/{{name}}"
	docker_args=(
		--name "claude-{{name}}"
		--hostname "claude-{{name}}"
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
	echo "  API key users:       already authenticated via .env"
	echo "  Start Claude:        just claude {{name}}"

start name:
	docker start "claude-{{name}}"

stop name:
	docker stop "claude-{{name}}"

restart name:
	docker restart "claude-{{name}}"

destroy name:
	@echo "Removing container claude-{{name}} (project files kept)..."
	docker rm -f "claude-{{name}}" 2>/dev/null || true
	@echo "Done. Project files still at: {{projects_dir}}/{{name}}"

# ── claude ─────────────────────────────────────────────────────────────────────

login name:
	just _ensure_running {{name}}
	docker exec -it "claude-{{name}}" claude login

claude name prompt="":
	#!/usr/bin/env bash
	set -euo pipefail
	status=$(docker inspect -f '{{{{.State.Status}}}}' "claude-{{name}}" 2>/dev/null || echo "missing")
	if [ "$status" = "missing" ]; then
		echo "ERROR: Container 'claude-{{name}}' does not exist. Run: just create {{name}}"
		exit 1
	elif [ "$status" = "exited" ] || [ "$status" = "created" ]; then
		echo "Container stopped — starting it..."
		docker start "claude-{{name}}"
		sleep 1
	fi
	if [ -n "{{prompt}}" ]; then
		docker exec -it "claude-{{name}}" claude --dangerously-skip-permissions -p "{{prompt}}"
	else
		docker exec -it "claude-{{name}}" claude --dangerously-skip-permissions
	fi

claude-safe name prompt="":
	#!/usr/bin/env bash
	set -euo pipefail
	status=$(docker inspect -f '{{{{.State.Status}}}}' "claude-{{name}}" 2>/dev/null || echo "missing")
	if [ "$status" = "missing" ]; then
		echo "ERROR: Container 'claude-{{name}}' does not exist. Run: just create {{name}}"
		exit 1
	elif [ "$status" = "exited" ] || [ "$status" = "created" ]; then
		echo "Container stopped — starting it..."
		docker start "claude-{{name}}"
		sleep 1
	fi
	if [ -n "{{prompt}}" ]; then
		docker exec -it "claude-{{name}}" claude -p "{{prompt}}"
	else
		docker exec -it "claude-{{name}}" claude
	fi

# ── shell & files ──────────────────────────────────────────────────────────────

shell name:
	just _ensure_running {{name}}
	docker exec -it "claude-{{name}}" bash

cp-to name src dest:
	docker cp "{{src}}" "claude-{{name}}:{{dest}}"

cp-from name src dest:
	docker cp "claude-{{name}}:{{src}}" "{{dest}}"

# ── monitoring ─────────────────────────────────────────────────────────────────

list:
	@docker ps -a --filter "name=claude-" --format "table {{{{.Names}}}}\t{{{{.Status}}}}\t{{{{.CreatedAt}}}}" | sed 's/claude-//g'

logs name:
	docker logs "claude-{{name}}"

stats:
	docker stats $(docker ps --filter "name=claude-" --format "{{{{.Names}}}}" | tr '\n' ' ')

# ── internal helpers ───────────────────────────────────────────────────────────

_ensure_running name:
	#!/usr/bin/env bash
	set -euo pipefail
	status=$(docker inspect -f '{{{{.State.Status}}}}' "claude-{{name}}" 2>/dev/null || echo "missing")
	if [ "$status" = "missing" ]; then
		echo "ERROR: Container 'claude-{{name}}' does not exist."
		echo "Run: just create {{name}}"
		exit 1
	elif [ "$status" = "exited" ] || [ "$status" = "created" ]; then
		echo "Container 'claude-{{name}}' is stopped — starting it..."
		docker start "claude-{{name}}"
		sleep 1
	fi
