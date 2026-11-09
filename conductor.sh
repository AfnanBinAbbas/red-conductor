#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib/checkpoint.sh"

usage() {
  cat <<'EOF'
redteam-scripts conductor — deterministic phase runner (red-conductor without the AI)

Usage:
  ./conductor.sh --target <host|url|ip> [options]
  ./conductor.sh --target example.com --phase recon,survey
  ./conductor.sh --target 10.10.10.5 --mode ctf --phase recon,survey,web,report

Phases (run order):
  recon     01-recon.sh        -> recon/recon.json
  survey    02-survey.sh       -> survey/hosts.json, endpoints.json, nuclei.txt
  web       03-web-checks.sh   -> exploit/findings-raw.md  (check batteries; AI interprets)
  infra     04-infra-checks.sh -> exploit/findings-raw.md  (panel/CVE/creds/drupal/mail)
  exfil     05-exfil.sh        -> loot/  (IDOR enum, log-PII, db dump chain)
  report    06-report.sh       -> report/findings.json + report.md skeleton
  validate  07-validate.sh     -> report/validation.md (adversarial re-check)

Options:
  --target <t>      required
  --ws <path>       workspace (default ~/redteam-runs/<target>/<ts>)
  --mode ctf|engagement
  --egress direct|tor
  --delay <sec>
  --phase a,b,c     subset (default: recon,survey)
  --force           ignore existing checkpoints
  --list            show phase status for --ws
  --help

Checkpoint rule: if output exists, phase is skipped. Never re-scan.
After web/infra batteries, hand the workspace to an AI agent to interpret
findings-raw.md and prove impact (scripts do mechanics, AI does judgment).
EOF
}

PHASE_ORDER=(recon survey web infra exfil validate report)

resolve_script() {
  local rel="$1" cand
  for cand in "$RTS_ROOT/$rel" "$RTS_ROOT/../$rel" "$RTS_ROOT"/*/"$rel" "$RTS_ROOT"/../*/"$rel"; do
    [[ -f "$cand" ]] && { echo "$cand"; return 0; }
  done
  return 1
}

run_phase() {
  local phase="$1" script rel
  case "$phase" in
    recon)  rel="phases/01-recon.sh" ;;
    survey) rel="phases/02-survey.sh" ;;
    web)    rel="phases/03-web-checks.sh" ;;
    infra)  rel="phases/04-infra-checks.sh" ;;
    exfil)  rel="phases/05-exfil.sh" ;;
    report) rel="phases/06-report.sh" ;;
    validate) rel="phases/07-validate.sh" ;;
    *) die "unknown phase: $phase" ;;
  esac
  script="$(resolve_script "$rel")" || die "script $rel not found — clone the phase repo as a sibling of red-conductor"
  log "PHASE START: $phase ($script)"
  bash "$script" \
    --target "$TARGET" --ws "$WS" --mode "$MODE" \
    --egress "$EGRESS" --delay "$DELAY" \
    $( [[ $FORCE -eq 1 ]] && echo --force ) \
    $( [[ -n "$OUT" ]] && echo --out "$OUT" ) \
    ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
}

main() {
  if [[ "${1:-}" == "--list" ]]; then
    shift
    parse_common_args "$@"
    init_workspace
    for p in "${PHASE_ORDER[@]}"; do
      printf '%-8s %s\n' "$p" "$(phase_status "$p")"
    done
    exit 0
  fi
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || $# -eq 0 ]]; then
    usage; exit 0
  fi
  parse_common_args "$@"
  init_workspace

  local selected=()
  if [[ -n "$PHASES" ]]; then
    IFS=',' read -r -a selected <<< "$PHASES"
  else
    selected=(recon survey)
  fi

  local p
  for p in "${selected[@]}"; do
    p="$(echo "$p" | tr -d '[:space:]')"
    [[ -n "$p" ]] || continue
    run_phase "$p"
  done

  log "conductor finished: $WS"
  echo "$WS"
}

main "$@"
