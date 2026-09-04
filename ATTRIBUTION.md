# Attribution — nvm-ps | Atribución — nvm-ps

> 🌐 **Language / Idioma:** [English (US)](#english-united-states-en-us--bcp-47-en-us) | [Español (España)](#español-españa-es-es--bcp-47-es-es)
> Standards: [BCP 47](https://www.rfc-editor.org/info/bcp47), [ISO 639-1](https://en.wikipedia.org/wiki/ISO_639-1), [ISO 3166-1 alpha-2](https://en.wikipedia.org/wiki/ISO_3166-1), [Microsoft Language Portal](https://www.microsoft.com/en-us/language)

---

## English (United States — en-US) — BCP 47 `en-US`

**All tool credits belong to the original creators.**

- **Original project:** [nvm-sh/nvm](https://github.com/nvm-sh/nvm) — Node Version Manager (POSIX bash)
- **Original authors:** Tim Caswell <tim@creationix.com>, Matthew Ranney, Jordan Harband (@ljharb), and OpenJS Foundation contributors
- **Original license:** MIT — see `LICENSE.md` in this repo and upstream https://github.com/nvm-sh/nvm/blob/master/LICENSE.md
- **Governance / Charter / Code of Conduct:** see upstream `GOVERNANCE.md`, `PROJECT_CHARTER.md`, `CODE_OF_CONDUCT.md`

### Fork (en-US)

- **Fork/Port:** **nvm-ps** — Windows 11 + PowerShell 7+ port of `nvm-sh` v0.40.7
- **Fork author:** **Luis Mendez** ([@luismmusic](https://github.com/luismmusic))
- **Reason:** Pure curiosity about the viability of porting `nvm-sh` to native Windows without WSL/Git Bash. Behavior, not just translation.
- **Claim:** No credit is claimed for the tool itself; this fork is an experimental curiosity. Color, behavior, and folder/file terminology follow en-US conventions.
- **CLI:** Remains `nvm` for 1:1 parity with `nvm-sh` (e.g., `nvm install`, `nvm use`)
- **Module:** `nvm-ps.psm1`, `nvm-ps.psd1` — `irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex` (PowerShell 7+ on Windows 11)
- **How it was made (logical and coherent):**
  - **Initial port (`nvm.sh` → PowerShell):** done in **Antigravity** (translation `nvm.sh` → `nvm-ps.psm1`/`psd1`/`install.ps1`)
  - **Adversarial audit, testing, final validation and publishing docs:** done in **opencode with oh-my-openagent** — hyperplan team `gap-hunter`/`win11-fidelity`/`edge-cases`/`docs-completeness` + `plan` (3 rounds, defended bundle `ses_f9b7fe778ffeCWS31Gd3vaglpC`, Waves 0–4, verdict: *not yet 1:1*, 16 deltas, 8 P0 blockers)

### Upstream first (en-US)

Bugs that reproduce on `nvm-sh` should be reported upstream at https://github.com/nvm-sh/nvm/issues.
Windows-specific issues for this port belong here: https://github.com/luismmusic/nvm-ps/issues

---

## Español (España — es-ES) — BCP 47 `es-ES`

**Todos los créditos de la herramienta pertenecen a los creadores originales.**

- **Proyecto original:** [nvm-sh/nvm](https://github.com/nvm-sh/nvm) — Node Version Manager (bash POSIX)
- **Autores originales:** Tim Caswell <tim@creationix.com>, Matthew Ranney, Jordan Harband (@ljharb) y contribuidores de OpenJS Foundation
- **Licencia original:** MIT — ver `LICENSE.md` en este repositorio y https://github.com/nvm-sh/nvm/blob/master/LICENSE.md
- **Gobernanza / Carta / Código de conducta:** ver `GOVERNANCE.md`, `PROJECT_CHARTER.md`, `CODE_OF_CONDUCT.md` del proyecto original

### Fork (es-ES — jerga de España)

- **Fork/Port:** **nvm-ps** — port a Windows 11 + PowerShell 7+ de `nvm-sh` v0.40.7
- **Autor del fork:** **Luis Mendez** ([@luismmusic](https://github.com/luismmusic))
- **Motivo:** Mera curiosidad por la viabilidad de portar `nvm-sh` a Windows nativo sin WSL/Git Bash. Comportamiento, no solo traducción. Se usa jerga de España: *ordenador* (no *computadora*), *carpeta* (no *directorio* genérico), *fichero/archivo*, *personalizar*.
- **Reivindicación:** No se reclama ningún crédito por la herramienta; este fork es un experimento de curiosidad. Color, comportamiento y terminología de carpeta/fichero siguen convenciones es-ES.
- **CLI:** Sigue siendo `nvm` para paridad 1:1 con `nvm-sh` (p. ej., `nvm install`, `nvm use`)
- **Módulo:** `nvm-ps.psm1`, `nvm-ps.psd1` — `irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex` (PowerShell 7+ en Windows 11, ordenador con Windows 11)
- **Cómo se hizo (lógico y coherente):**
  - **Port inicial (`nvm.sh` → PowerShell):** realizado en **Antigravity** (traducción `nvm.sh` → `nvm-ps.psm1`/`psd1`/`install.ps1`)
  - **Auditoría adversarial, pruebas, validación final y documentación para publicación:** realizadas en **opencode con oh-my-openagent** — equipo hyperplan `gap-hunter`/`win11-fidelity`/`edge-cases`/`docs-completeness` + `plan` (3 rondas, bundle defendido `ses_f9b7fe778ffeCWS31Gd3vaglpC`, Waves 0–4, veredicto: *aún no 1:1*, 16 deltas, 8 P0)

### Upstream primero (es-ES)

Los errores que también reproducen en `nvm-sh` deben reportarse upstream en https://github.com/nvm-sh/nvm/issues.
Los incidencias específicas de Windows para este port, aquí: https://github.com/luismmusic/nvm-ps/issues
