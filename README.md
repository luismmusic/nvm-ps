# nvm-ps — Node Version Manager for Windows 11 + PowerShell 7+

> **Fork/Port of [nvm-sh/nvm](https://github.com/nvm-sh/nvm) (`nvm.sh` v0.40.7) to native Windows 11 + PowerShell 7+.**
> **CLI remains `nvm` for 1:1 parity (`nvm install`/`use`/`ls`). Module/product is `nvm-ps`.**

<p align="center">
  <a href="https://github.com/nvm-sh/nvm"><img src="https://raw.githubusercontent.com/nvm-sh/logos/HEAD/nvm-logo-color.svg" height="50" alt="nvm logo" /></a>
</p>

[![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-blue.svg)](https://github.com/PowerShell/PowerShell)
[![Windows 11](https://img.shields.io/badge/Windows-11-0078D6.svg)](https://www.microsoft.com/windows)
[![Version](https://img.shields.io/badge/nvm--ps-v0.40.7-yellow.svg)](https://github.com/luismmusic/nvm-ps)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/nvm-sh/nvm/blob/master/LICENSE.md)

---

## ⚠️ Créditos — Todos los créditos pertenecen a los creadores originales

**Esta herramienta es íntegramente de [nvm-sh](https://github.com/nvm-sh/nvm):** [Tim Caswell](https://github.com/creationix) `tim@creationix.com`, [Matthew Ranney](https://github.com/mranney), [Jordan Harband](https://github.com/ljharb) (`@ljharb`) y los contribuidores de **OpenJS Foundation** — ver [`LICENSE.md`](LICENSE.md), [`CONTRIBUTING.md`](CONTRIBUTING.md), [`GOVERNANCE.md`](GOVERNANCE.md).

**Fork/Port por Luis Mendez ([@luismmusic](https://github.com/luismmusic)) — por mera curiosidad de su viabilidad.** No se reclama crédito alguno por la herramienta; este fork existe solo como experimento de portar `nvm-sh` (POSIX bash) a **Windows 11 nativo con PowerShell 7+**, sin WSL/Git Bash.

> **Autoría del fork — expresado de forma lógica y coherente:**
> - **Port inicial (traducción `nvm.sh` → `nvm-ps.psm1`/`nvm-ps.psd1`/`install.ps1`):** realizado en **Antigravity**.
> - **Auditoría adversarial hyperplan, pruebas, validación final y documentación para publicación:** realizadas en **opencode con oh-my-openagent** (agentes `gap-hunter`, `win11-fidelity`, `edge-cases`, `docs-completeness` + `plan` — 3 rondas + bundle defendido `ses_f9b7fe778ffeCWS31Gd3vaglpC`).
> - **Fork completo por Luis Mendez** — toda la lógica pertenece a `nvm-sh`; este fork es solo el experimento de port.

Si te gusta la herramienta, da estrella y contribuye upstream: **[nvm-sh/nvm](https://github.com/nvm-sh/nvm)**.

> *Nota hyperplan (opencode/oh-my-openagent):* auditoría 2026-09-03 concluyó que el port **NO es aún 1:1** (16 deltas, 8 P0 bloquean ship) — ver `.omo/plans/nvm-ps-port-audit.md`. El header `nvm-ps.psm1` reclamará 1:1 solo tras P0-QA.

---

## 📦 Instalación — Windows 11 + PowerShell 7+

> **Requiere PowerShell 7.4+** (`winget install Microsoft.Powershell`) — 7.6+ recomendado. No requiere `Microsoft.Coreutils`, `WSL`, ni `Git Bash`. Puro `.NET`.

### Opción A — Instalación en una línea (recomendada)

Abre **Windows Terminal / PowerShell 7+** (no Windows PowerShell 5.1):

```powershell
irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex
```

Esto:
- crea `$env:USERPROFILE\.nvm` (o respeta `$env:NVM_DIR` existente),
- copia `nvm-ps.psm1`/`nvm-ps.psd1`/`nvm-exec.ps1`/`completions/nvm-ps.ArgumentCompleter.ps1` a `$NVM_DIR`,
- añade a tu `$PROFILE` (`Microsoft.PowerShell_profile.ps1`):
  ```powershell
  if (Test-Path "$env:NVM_DIR\nvm-ps.psm1") { Import-Module "$env:NVM_DIR\nvm-ps.psm1" -DisableNameChecking }
  ```
- y antepone la versión `default` si existe.

Reinicia la terminal o haz:

```powershell
Import-Module "$env:NVM_DIR\nvm-ps.psm1" -DisableNameChecking
nvm --help
```

### Opción B — Local (clonando el fork)

```powershell
git clone https://github.com/luismmusic/nvm-ps.git
cd nvm-ps
.\nvm-ps\install.ps1           # respeta $env:NVM_DIR, usa -NoProfile para no tocar $PROFILE
.\nvm-ps\install.ps1 -NvmDir "$env:USERPROFILE\.nvm-ps" -NoProfile
```

### Verificar instalación

```powershell
Get-Command nvm              # debe mostrar Function nvm
nvm --version               # 0.40.7
nvm ls                      # lista instaladas
Test-ModuleManifest ./nvm-ps/nvm-ps.psd1  # debe salir sin error
```

---

## 🚀 Uso (CLI `nvm` — idéntico a `nvm-sh`)

```powershell
nvm install 24              # instala Node 24.latest (usa .nvmrc si se omite versión)
nvm install --lts           # latest LTS
nvm use 20
node -v                     # v20.x.y
nvm ls                      # instaladas
nvm ls-remote               # remotas (requiere internet)
nvm alias default 20
nvm which 20               # path a node.exe
nvm current
nvm deactivate             # restaura PATH
nvm unload                 # descarga módulo
```

Todas las flags de `nvm-sh` están portadas (`--lts`, `--reinstall-packages-from`, `--latest-npm`, `--offline`, etc.) salvo `nvm install -s` (compilar desde fuente no soportado en Windows — aborta con mensaje explícito, ver Caveats).

---

## Windows caveats (vs `nvm-sh`)

| Tema | Detalle |
|------|---------|
| **ExecutionPolicy** | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` si `irm|iex` es bloqueado. |
| **LongPaths** | Activa `HKLM\SYSTEM\CurrentControlSet\Control\FileSystem\LongPathsEnabled=1` y `git config --global core.longpaths true`. |
| **Defender** | Excluye `$NVM_DIR` en tiempo real si ves `EPERM` en extracción. |
| **CRLF/BOM** | `.nvmrc` debe ser UTF-8 sin BOM, LF preferido; `nvm_process_nvmrc_content` hace `TrimStart(0xFEFF)`. |
| **Proxy** | Usa `$env:HTTP_PROXY`/`HTTPS_PROXY`; `Invoke-WebRequest` respeta `-Proxy`. |
| **Source (`-s`)** | `nvm install -s 14` → `not supported on Windows` (usa binario). |
| **Symlinks** | Requiere **Developer Mode** o terminal elevada para `New-Item -ItemType SymbolicLink`. |
| **Microsoft.Coreutils** | **No requerido**. `nvm-ps` no depende de `winget install Microsoft.Coreutils` / `uutils`; es opcional si quieres pipelines Linux puros. |

---

## 🔗 nvm-sh vs nvm-ps

|  | `nvm-sh` (upstream) | `nvm-ps` (este fork) |
|---|---|---|
| **Plataforma** | Linux/macOS/WSL, POSIX bash/zsh/dash | **Windows 11**, PowerShell 7+ |
| **Módulo** | `nvm.sh` (4670 lín.) | `nvm-ps/nvm-ps.psm1` (2938 lín.) |
| **CLI** | `nvm` | `nvm` (mismo) |
| **Instalador** | `install.sh` (`curl|bash`) | `install.ps1` (`irm|iex`) |
| **Completions** | `bash_completion` | `nvm-ps.ArgumentCompleter.ps1` |
| **Tests** | `urchin` (`test/fast`, `test/slow`) | `Pester` (`tests/*.Tests.ps1`) — en progreso P0-QA |
| **Dependencias** | `curl/wget, tar, sha256sum, grep/sed/awk/sort` | **ninguna externa** (`.NET` puro) |

Migración desde `nvm-windows/` (nombre previo del port en este repo): `nvm-ps` mantiene shim `nvm-windows/nvm.psm1` que redirige a `nvm-ps.psm1` con warning. Elimina `nvm-windows/` en tu próximo clone limpio.

---

## 📚 Documentación

- `nvm --help` — ayuda completa (respeta `--no-colors`)
- `README.md` (este archivo) — instalación Windows
- Upstream: [nvm-sh README](https://github.com/nvm-sh/nvm#readme), [install & update](https://github.com/nvm-sh/nvm#installing-and-updating), [.nvmrc](https://github.com/nvm-sh/nvm#nvmrc)

---

## 🤝 Contribuir

Issues/PRs bienvenidos en **este fork** para Windows; para lógica core/port 1:1, por favor también abre upstream en [nvm-sh/nvm](https://github.com/nvm-sh/nvm/issues).

- Requiere `PSScriptAnalyzer` clean: `Invoke-ScriptAnalyzer -Path ./nvm-ps -Recurse -Severity Warning`
- Tests: `Invoke-Pester -Path ./tests -CI` (≥40 casos tras P0-QA)

---

## 📄 Licencia

MIT — ver [`LICENSE.md`](LICENSE.md). Copyright **(c) OpenJS Foundation and nvm-sh contributors** — fork `nvm-ps` por **Luis Mendez** (curiosidad).

---

## 🔧 Comando de instalación copiable

```powershell
# Windows 11 + PowerShell 7+ — nvm-ps (fork de nvm-sh por Luis Mendez)
irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex; nvm --help
```
