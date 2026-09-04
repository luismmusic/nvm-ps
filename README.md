# nvm-ps — Node Version Manager for Windows 11 + PowerShell 7+

> **Fork/Port of [nvm-sh/nvm](https://github.com/nvm-sh/nvm) (`nvm.sh` v0.40.7) to native Windows 11 + PowerShell 7+.**
> **CLI remains `nvm` for 1:1 parity (`nvm install`/`use`/`ls`). Module/product is `nvm-ps`.**

> 🌐 **Language:** **English (US)** | [Español (España)](README.es-ES.md)

<p align="center">
  <a href="https://github.com/nvm-sh/nvm"><img src="https://raw.githubusercontent.com/nvm-sh/logos/HEAD/nvm-logo-color.svg" height="50" alt="nvm logo" /></a>
</p>

[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows 11](https://img.shields.io/badge/Windows-11-0078D6.svg)](https://www.microsoft.com/windows)
[![Version](https://img.shields.io/badge/nvm--ps-v0.40.7-yellow.svg)](https://github.com/luismmusic/nvm-ps)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/nvm-sh/nvm/blob/master/LICENSE.md)

---

## ⚠️ Credits — All credits belong to the original creators

**This tool is entirely from [nvm-sh](https://github.com/nvm-sh/nvm):** [Tim Caswell](https://github.com/creationix) `tim@creationix.com`, [Matthew Ranney](https://github.com/mranney), [Jordan Harband](https://github.com/ljharb) (`@ljharb`) and the **OpenJS Foundation** contributors — see [`LICENSE.md`](LICENSE.md).

**Fork/Port by Luis Mendez ([@luismmusic](https://github.com/luismmusic)) — out of pure curiosity about its viability.** No credit is claimed for the tool itself; this fork exists solely as an experiment porting `nvm-sh` (POSIX bash) to **native Windows 11 with PowerShell 7+**, without WSL/Git Bash.

> **Fork authorship — stated logically and coherently (per applicable standards — BCP 47, ISO 639-1/3166-1, Microsoft Language Portal):**
> - **Initial port (`nvm.sh` → `nvm-ps.psm1`/`nvm-ps.psd1`/`install.ps1`):** done in **Antigravity**.
> - **Adversarial audit (hyperplan), testing, final validation and publishing docs:** done in **opencode with oh-my-openagent** (agents `gap-hunter`, `win11-fidelity`, `edge-cases`, `docs-completeness` + `plan` — 3 rounds + defended bundle `ses_f9b7fe778ffeCWS31Gd3vaglpC`).
> - **Entire fork by Luis Mendez** — all logic belongs to `nvm-sh`; this fork is just the port experiment.

If you like the tool, please star and contribute upstream: **[nvm-sh/nvm](https://github.com/nvm-sh/nvm)**.

> *Hyperplan note (opencode/oh-my-openagent):* adversarial audit on 2026-09-03 concluded the port is **not yet 1:1** (16 deltas, 8 P0 blockers). The `nvm-ps.psm1` header will claim 1:1 only after P0-QA passes.

---

## 📦 Installation — Windows 11 + PowerShell 7+

> **Requires PowerShell 7.4+** (`winget install Microsoft.Powershell`) — 7.6+ recommended. No `Microsoft.Coreutils`, `WSL`, or `Git Bash` required. Pure `.NET`.

### Option A — One-line install (recommended)

Open **Windows Terminal / PowerShell 7+** (not Windows PowerShell 5.1):

```powershell
irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex
```

This will:
- create `$env:USERPROFILE\.nvm` (or respect existing `$env:NVM_DIR`),
- copy `nvm-ps.psm1`/`nvm-ps.psd1`/`nvm-exec.ps1`/`completions/nvm-ps.ArgumentCompleter.ps1` to `$NVM_DIR`,
- add to your `$PROFILE` (`Microsoft.PowerShell_profile.ps1`):
  ```powershell
  if (Test-Path "$env:NVM_DIR\nvm-ps.psm1") { Import-Module "$env:NVM_DIR\nvm-ps.psm1" -DisableNameChecking }
  ```
- and prepend the `default` version if it exists.

Restart the terminal or run:

```powershell
Import-Module "$env:NVM_DIR\nvm-ps.psm1" -DisableNameChecking
nvm --help
```

### Option B — Local (cloning the fork)

```powershell
git clone https://github.com/luismmusic/nvm-ps.git
cd nvm-ps
.\install.ps1           # respects $env:NVM_DIR, use -NoProfile to skip $PROFILE
.\install.ps1 -NvmDir "$env:USERPROFILE\.nvm-ps" -NoProfile
```

### Verify installation

```powershell
Get-Command nvm              # should show Function nvm
nvm --version                # 0.40.7
nvm ls                       # list installed versions
Test-ModuleManifest ./nvm-ps.psd1  # should exit without error
```

---

## 🚀 Usage (CLI `nvm` — identical to `nvm-sh`)

```powershell
nvm install 24              # installs Node 24.latest (uses .nvmrc if version omitted)
nvm install --lts           # latest LTS
nvm use 20
node -v                     # v20.x.y
nvm ls                      # installed versions
nvm ls-remote               # remote versions (requires internet)
nvm alias default 20
nvm which 20                # path to node.exe
nvm current
nvm deactivate              # restores PATH
nvm unload                  # unloads module
```

All `nvm-sh` flags are ported (`--lts`, `--reinstall-packages-from`, `--latest-npm`, `--offline`, etc.) except `nvm install -s` (compile from source not supported on Windows — aborts with an explicit message, see Caveats).

---

## Windows caveats (vs `nvm-sh`)

| Topic | Details |
|-------|---------|
| **ExecutionPolicy** | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` if `irm|iex` is blocked. |
| **LongPaths** | Enable `HKLM\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled=1` and `git config --global core.longpaths true`. |
| **Defender** | Exclude `$NVM_DIR` from real-time scanning if you see `EPERM` on extraction. |
| **CRLF/BOM** | `.nvmrc` must be UTF-8 without BOM, LF preferred; `nvm_process_nvmrc_content` does `TrimStart(0xFEFF)`. |
| **Proxy** | Use `$env:HTTP_PROXY`/`HTTPS_PROXY`; `Invoke-WebRequest` respects `-Proxy`. |
| **Source (`-s`)** | `nvm install -s 14` → `not supported on Windows` (use binary). |
| **Symlinks** | Requires **Developer Mode** or an elevated terminal for `New-Item -ItemType SymbolicLink`. |
| **Microsoft.Coreutils** | **Not required**. `nvm-ps` does not depend on `winget install Microsoft.Coreutils` / `uutils`; optional only if you want native Linux pipelines. |

---

## 🔗 nvm-sh vs nvm-ps

|  | `nvm-sh` (upstream) | `nvm-ps` (this fork) |
|---|---|---|
| **Platform** | Linux/macOS/WSL, POSIX bash/zsh/dash | **Windows 11**, PowerShell 7+ |
| **Module** | `nvm.sh` (4670 lines) | `nvm-ps.psm1` (2938 lines) |
| **CLI** | `nvm` | `nvm` (same) |
| **Installer** | `install.sh` (`curl|bash`) | `install.ps1` (`irm|iex`) |
| **Completions** | `bash_completion` | `nvm-ps.ArgumentCompleter.ps1` |
| **Tests** | `urchin` (`test/fast`, `test/slow`) | `Pester` (`tests/*.Tests.ps1`) — P0-QA in progress |
| **Dependencies** | `curl/wget, tar, sha256sum, grep/sed/awk/sort` | **no external deps** (pure `.NET`) |

---

## 📚 Documentation

- `nvm --help` — full help (respects `--no-colors`)
- `README.md` (this file, en-US) / `README.es-ES.md` (es-ES) — Windows install — per [BCP 47](https://www.rfc-editor.org/info/bcp47) / [ISO 639-1](https://en.wikipedia.org/wiki/ISO_639-1) + [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1) (en-US, es-ES) and [Microsoft Language Portal](https://www.microsoft.com/en-us/language)
- Upstream: [nvm-sh README](https://github.com/nvm-sh/nvm#readme), [install & update](https://github.com/nvm-sh/nvm#installing-and-updating), [.nvmrc](https://github.com/nvm-sh/nvm#nvmrc)

---

## 🤝 Contributing

Issues/PRs welcome in **this fork** for Windows; for core logic / 1:1 port, please also open upstream at [nvm-sh/nvm](https://github.com/nvm-sh/nvm/issues).

- Requires `PSScriptAnalyzer` clean: `Invoke-ScriptAnalyzer -Path . -Recurse -Severity Warning`
- Tests: `Invoke-Pester -Path ./tests -CI` (≥40 cases after P0-QA)

---

## 📄 License

MIT — see [`LICENSE.md`](LICENSE.md). Copyright **(c) OpenJS Foundation and nvm-sh contributors** — fork `nvm-ps` by **Luis Mendez** (curiosity experiment).

---

## 🔧 Copy-paste install command

```powershell
# Windows 11 + PowerShell 7+ — nvm-ps (fork of nvm-sh by Luis Mendez)
irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex; nvm --help
```
