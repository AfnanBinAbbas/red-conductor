# red-conductor

Deterministic orchestrator for the red-team phase pipeline — runs without an AI in
the loop for the mechanical parts. Phase exists → skip (scan-once contract);
phase missing → run; after batteries → hand workspace to AI for judgment.

## Hub install

Clone every phase repo as a SIBLING of this one:

```bash
mkdir -p ~/redteam-hub && cd ~/redteam-hub
git clone <this-repo> red-conductor
git clone <red-recon>
git clone <red-survey>
git clone <red-exploit-web>
git clone <red-exploit-infra>
git clone <red-privesc>
git clone <red-exfil>
git clone <red-validate>
git clone <red-report>
```

## Usage

```bash
cd red-conductor
./conductor.sh --target example.com                        # recon+survey
./conductor.sh --target 10.10.10.5 --mode ctf --phase recon,survey,web,infra,exfil,validate,report
./conductor.sh --target host --egress tor --phase web,infra
./conductor.sh --list --target example.com --ws ~/redteam-runs/example.com/<ts>
```

## Options

`--target` (required), `--ws`, `--mode ctf|engagement`, `--egress direct|tor`,
`--delay <sec>`, `--phase a,b,c`, `--force`, `--list`.

## Contract

- Checkpoints per PLAYBOOK: recon.json → hosts.json/endpoints.json → findings-raw.md → loot/ → report.
- Never re-run a scan; `--force` overrides.
- Batteries emit CANDIDATES into findings-raw.md; AI proves impact before any claim.
- OPSEC: 3s default delay, cred cap 30, abort on transport failure (possible block), Tor egress option.

Authorized targets only.
