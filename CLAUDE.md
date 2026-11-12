# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Pure Bash scripts that tune a Linux server (VPS/dedicated, not desktops): system update, packages, swap, sysctl, sshd, ulimits, UFW, and optionally the XanMod kernel (Ubuntu/Debian only). Must run as root. Supported: Ubuntu 22.04+, Debian 12+, CentOS Stream 8+, AlmaLinux 8+, Fedora 37+.

There is no build system and no test suite. Lint with:

```
shellcheck linux-optimizer.sh scripts/*.sh
bash -n scripts/ubuntu-optimizer.sh   # syntax check one file
```

The scripts change system files (`/etc/sysctl.conf`, `/etc/ssh/sshd_config`, `/etc/profile`, `/etc/hosts`, `/etc/resolv.conf`), so only run them on a disposable Linux VM, never on the dev machine.

## Architecture

- `linux-optimizer.sh` is the entry point users `wget` from GitHub. It checks root, detects the OS from `NAME=` in `/etc/os-release`, installs deps (`wget curl sudo jq`), fixes `/etc/hosts`, temporarily rewrites DNS, sets the timezone from IP geolocation, then **downloads the per-distro script from `raw.githubusercontent.com/hawshemi/Linux-Optimizer/main/scripts/`** and runs it. Local edits to `scripts/*.sh` are therefore not used when running the launcher; run the distro script directly to test it.
- `scripts/{ubuntu,debian,centos,fedora}-optimizer.sh` are self-contained, interactive menu scripts (`show_menu` + `main` loop + `apply_everything`). AlmaLinux reuses `centos-optimizer.sh`. Ubuntu/Debian use `apt` and have `install_xanmod` (Ubuntu also `disable_terminal_ads`); CentOS/Fedora use `dnf` and have no kernel option, so menu numbering differs between the two families.
- The four distro scripts are heavily duplicated: same function names (`complete_update`, `installations`, `swap_maker`, `sysctl_optimizations`, `remove_old_ssh_conf`, `update_sshd_conf`, `limits_optimizations`, `find_ssh_port`, `ufw_optimizations`, `ask_reboot`) and near-identical bodies. A tuning change usually has to be applied to all four.
- Config is written inline via heredocs, not read from `files/`. `files/sysctl.conf`, `files/sshd_config`, `files/profile` are reference copies linked from the README and script comments; keep them in sync with the heredocs by hand.
- Each config step backs up the original (`*.bak`), deletes existing keys with a long `sed -i -e '/key/d'` list, then appends the heredoc. When adding a sysctl/sshd key, add it to both the `sed` delete list and the heredoc, or repeated runs will duplicate it.
- Output uses the shared `green_msg` / `yellow_msg` / `red_msg` helpers (defined at the top of every script).
- When adding a menu step or option, update `README.md`'s numbered task list as well.
