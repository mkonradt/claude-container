# Getting Started: Claude Code Containers on Windows

This guide walks you through setting up isolated Docker containers for running Claude Code on Windows, using **WSL2 + Docker Desktop**.

---

## The Big Picture

A container is like a lightweight virtual computer running inside your real computer. It has its own Linux operating system, its own installed programs, and its own files — but it starts in seconds and uses very little memory.

The key idea: Claude Code runs *inside* the container and can make a mess in there all day long. Your Windows files stay completely untouched. A shared folder (called a bind mount) lets you exchange files back and forth. Your work survives even if the container is destroyed — the container is disposable, the project folder is permanent.

On Mac this setup uses Colima as the Docker runtime. On Windows the equivalent is **WSL2** (a real Linux environment built into Windows) with **Docker Desktop** running on top of it.

---

## Prerequisites

- Windows 10 version 2004 or later, or Windows 11
- Virtualization enabled in your BIOS (most modern PCs have this on by default)
- A Claude Pro or Max subscription, **or** an Anthropic API key

> **Do I have virtualization enabled?** Open Task Manager (`Ctrl+Shift+Esc`), click the Performance tab, click CPU. If you see "Virtualization: Enabled" you are good. If it says Disabled, search for your PC model + "enable virtualization" for BIOS instructions.

---

## Part 1: Install WSL2

WSL2 (Windows Subsystem for Linux 2) creates a real Linux environment inside Windows. This is where Docker and Claude Code will actually run.

Open **PowerShell as Administrator** — search for PowerShell in the Start menu, right-click, choose "Run as administrator" — then run:

```powershell
wsl --install
```

This installs WSL2 with Ubuntu automatically. **Restart your computer** when it finishes.

After restarting, Ubuntu will open and ask you to create a Linux username and password. Choose something simple — this is separate from your Windows password.

> **Already have WSL1?** Check with `wsl -l -v` in PowerShell. If your distro shows VERSION 1, upgrade it with `wsl --set-version Ubuntu 2`.

---

## Part 2: Install Docker Desktop

1. Download Docker Desktop from **https://www.docker.com/products/docker-desktop/**
2. Run the installer. When asked, make sure **"Use WSL 2 instead of Hyper-V"** is checked.
3. Restart your computer when prompted.
4. After restart, Docker Desktop opens — accept the terms and let it finish starting up (the whale icon in your system tray stops animating).

**Enable WSL2 integration:** Docker Desktop → Settings → Resources → WSL Integration → enable integration with your Ubuntu distro → Apply & Restart.

**Verify Docker works.** Open your Ubuntu terminal (search "Ubuntu" in Start menu) and run:

```bash
docker run hello-world
```

You should see "Hello from Docker!". If you do, Docker is working correctly.

---

## Part 3: Install Prerequisites Inside WSL2

All remaining steps happen inside your **Ubuntu terminal**, not PowerShell.

### Install Node.js

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
```

Verify: `node --version` should show v22 or higher.

### Install `just`

`just` is a command runner — it replaces long complicated commands with short ones like `just build` or `just create my-project`.

```bash
curl --proto '=https' --tlsv1.2 -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

Verify: `just --version` should print a version number.

### Install Git

```bash
sudo apt install -y git
```

---

## Part 4: Set Up SSH and Clone the Repository

GitHub requires SSH authentication. First generate an SSH key inside WSL2:

```bash
ssh-keygen -t ed25519 -C "your.email@example.com"
```

Hit Enter three times to accept defaults. Then copy your public key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Go to **github.com → Settings → SSH and GPG keys → New SSH key**, paste it and save.

Now clone your forked repo:

```bash
cd ~
git clone git@github.com:mkonradt/claude-container.git
cd claude-container
```

> **Important:** Keep this folder inside your Linux home directory (`/home/yourusername/`), not on your Windows C: drive. Accessing Windows files from WSL2 (paths under `/mnt/c/`) is significantly slower.

---

## Part 5: Configure Your API Key (API Key Users Only)

If you are using an Anthropic API key rather than a Claude Pro/Max subscription:

```bash
cp .env.example .env
nano .env
```

Replace `your_api_key_here` with your actual key from https://console.anthropic.com/. Save with `Ctrl+O`, Enter, then `Ctrl+X`.

**Subscription users:** skip this step — you will log in interactively in Part 8.

---

## Part 6: Verify Setup

```bash
just setup
```

This checks that Docker Desktop is running and reachable from WSL2. If it fails, make sure Docker Desktop is open on Windows and WSL2 integration is enabled (see Part 2).

---

## Part 7: Build the Container Image

```bash
just build
```

This downloads and assembles the container image with all tools pre-installed: Python, R, Node.js, DuckDB, Git, Claude Code CLI, and more. Takes a few minutes the first time. Future builds are much faster because Docker caches each step.

---

## Part 8: Create Your First Project

```bash
just create my-first-project
```

This creates a folder at `projects/my-first-project/` inside your `claude-container` directory. Anything Claude creates inside `/workspace` inside the container will appear here instantly.

To access these files from Windows Explorer, navigate to:

```
\\wsl$\Ubuntu\home\<your-linux-username>\claude-container\projects\
```

---

## Part 9: Log In to Claude

### Subscription users (Pro or Max)

```bash
just login my-first-project
```

This displays a URL — open it in your Windows browser, sign in with your Claude account, and the container is authenticated. You only need to do this once per container (it survives stop/start, but not destroy/recreate).

### API key users

No login needed. Your key was passed in automatically via `.env`.

---

## Part 10: Start Claude

```bash
just claude my-first-project
```

Claude's interface appears in your terminal. Type requests in plain English:

```
Create a Python script that reads all PDF files in /workspace and extracts all text to a CSV
```

```
Search for news articles about copper mine disruptions in the last 6 months and save a structured list to /workspace/events.csv
```

When you are done, press `Ctrl+C` or type `/exit`. The container keeps running in the background.

---

## Daily Workflow

Once set up, your day-to-day usage is just:

```bash
cd ~/claude-container
just claude my-first-project     # start a session
just stop my-first-project       # shut down when done
```

---

## Managing Multiple Projects

```bash
just create metal-shocks
just create green-capex
just claude metal-shocks
```

Each project has its own installed packages, history, and workspace folder — fully isolated from each other.

---

## Commands Reference

| Command | What it does |
|---|---|
| `just setup` | Verify Docker Desktop is running and accessible |
| `just build` | Build the container image (once) |
| `just create <n>` | Create a new project container |
| `just claude <n>` | Start Claude in YOLO mode (no permission prompts) |
| `just claude-safe <n>` | Start Claude with permission prompts |
| `just shell <n>` | Open a bash shell inside the container |
| `just start <n>` | Start a stopped container |
| `just stop <n>` | Stop a running container |
| `just login <n>` | Authenticate with Claude subscription |
| `just list` | Show all your containers |
| `just destroy <n>` | Delete the container (project files kept) |
| `just cp-to <n> <src> <dest>` | Copy files from WSL2 into the container |
| `just cp-from <n> <src> <dest>` | Copy files from container back out |

---

## YOLO Mode vs Safe Mode

The default `just claude` runs in YOLO mode (`--dangerously-skip-permissions`). Claude won't ask permission before creating files, running scripts, or making changes. This is safe because the container is the security boundary — Claude can only touch files inside `/workspace`, not your actual Windows system.

Use `just claude-safe` if you prefer to approve each action.

---

## Customising Claude's Behaviour

Edit these files, then run `just rebuild` to apply to all future containers:

- `config/CLAUDE.md` — standing instructions Claude reads at every session start. Add preferred libraries, output formats, project context, or any other guidance.
- `config/claude-settings.json` — permission settings and behaviour flags.

---

## Troubleshooting

**"Cannot connect to Docker" / "Docker daemon not running"**
Open Docker Desktop from the Start menu and wait for the whale icon to stop animating. Then try again.

**WSL Integration not working**
Docker Desktop → Settings → Resources → WSL Integration → enable your Ubuntu distro → Apply & Restart.

**"just: command not found"**
Run `source ~/.bashrc` to reload your PATH, then try again.

**Slow file access**
Make sure your `claude-container` folder is under `/home/username/` in WSL2, not under `/mnt/c/`. Cross-filesystem access is significantly slower.

**Container won't start after Windows restart**
Wait for Docker Desktop to fully start (whale icon stops animating), then run `just start <n>`.
