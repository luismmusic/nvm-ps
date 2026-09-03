# Attribution — nvm-ps

**All tool credits belong to the original creators.**

- **Original project:** [nvm-sh/nvm](https://github.com/nvm-sh/nvm) — Node Version Manager (POSIX bash)
- **Original authors:** Tim Caswell <tim@creationix.com>, Matthew Ranney, Jordan Harband (@ljharb), and OpenJS Foundation contributors.
- **Original license:** MIT — see `LICENSE.md` in this repo and upstream https://github.com/nvm-sh/nvm/blob/master/LICENSE.md
- **Governance / Charter / CoC:** see `GOVERNANCE.md`, `PROJECT_CHARTER.md`, `CODE_OF_CONDUCT.md` (upstream).

## Fork

- **Fork/Port:** **nvm-ps** — Windows 11 + PowerShell 7+ port of `nvm-sh` v0.40.7
- **Fork author:** **Luis Mendez** ([@luismmusic](https://github.com/luismmusic))
- **Reason:** Mera curiosidad por la viabilidad de portar `nvm-sh` a Windows nativo sin WSL/Git Bash.
- **Claim:** No credit is claimed for the tool itself. This fork is an experimental curiosity.
- **CLI:** Remains `nvm` for 1:1 parity with `nvm-sh`.
- **Module:** `nvm-ps` (`nvm-ps.psm1`, `nvm-ps/nvm-ps.psd1`).
- **Install:** `irm https://raw.githubusercontent.com/luismmusic/nvm-ps/master/install.ps1 | iex` (PowerShell 7+ on Windows 11)
- **How it was made (logical and coherent authorship):**
  - **Initial port (`nvm.sh` → PowerShell):** done in **Antigravity** (translation `nvm.sh` → `nvm-ps.psm1`/`psd1`/`install.ps1`).
  - **Adversarial audit, testing, final validation and publishing docs:** done in **opencode with oh-my-openagent** — hyperplan team `gap-hunter`/`win11-fidelity`/`edge-cases`/`docs-completeness` + `plan` (3 rounds, defended bundle `ses_f9b7fe778ffeCWS31Gd3vaglpC`, waves 0-4, veredicto: *not yet 1:1*, 16 deltas, 8 P0).

## Upstream first

Bugs that reproduce on `nvm-sh` should be reported upstream at https://github.com/nvm-sh/nvm/issues.
Windows-specific issues for this port belong here: https://github.com/luismmusic/nvm-ps/issues
