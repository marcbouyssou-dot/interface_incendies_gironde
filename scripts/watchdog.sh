#!/usr/bin/env bash
#
# MobSanté Watchdog — semi-automated local runner.
#
# Location: scripts/ rather than the JOB's suggested tools/, because
# scripts/ is this repo's existing, established location for standalone
# utility scripts (netlify_build.sh, backfill_*.mjs, ...); tools/ only
# holds Dart codegen helpers (generate_address_registry.dart,
# import_location_source.dart), a different category. No new top-level
# convention is introduced.
#
# Usage:
#   ./scripts/watchdog.sh [light|standard|deep]
#
# Default level: standard.
#
# Read-only and non-destructive:
#   - never runs git add / commit / push / pull / merge / rebase / stash ;
#   - never deploys, never migrates ;
#   - never fetches (no network dependency — origin/main is read from
#     whatever remote-tracking ref is already known locally) ;
#   - never modifies application code, JOB files, the Control Plane or the
#     JOB Queue.
#
# It implements a best-effort, purely mechanical subset of the checks
# defined in 99_AI/MOBSANTE_WATCHDOG.md. In particular it does NOT attempt
# to decide whether a locally modified file belongs to a given JOB: that
# attribution requires the PROVEN / PROBABLE / UNKNOWN evidence rules
# described in 99_AI/MOBSANTE_WATCHDOG.md → "Règles de rattachement
# changement ↔ JOB", which are not reliably automatable in shell. Every
# conclusion this script cannot support with a simple, verifiable rule is
# left explicitly marked REQUIRES_AI_REVIEW instead of being guessed.
#
# Output: a timestamped report under .ai/output/, e.g.
#   .ai/output/WATCHDOG_20260825_1830_STANDARD.md
#
# Exit status: always 0 on a completed run (the report itself carries the
# Global signal); non-zero only if the script could not run at all
# (not a Git repository, invalid level argument).

set -euo pipefail

# ---------------------------------------------------------------------------
# Level argument
# ---------------------------------------------------------------------------

level="${1:-standard}"
case "${level}" in
  light | standard | deep) ;;
  *)
    echo "Usage: $0 [light|standard|deep]" >&2
    exit 1
    ;;
esac

# ---------------------------------------------------------------------------
# Repo root / output path
# ---------------------------------------------------------------------------

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${repo_root}" ]]; then
  echo "watchdog.sh must be run inside a Git repository." >&2
  exit 1
fi
cd "${repo_root}"

output_dir=".ai/output"
mkdir -p "${output_dir}"

timestamp_file="$(date +%Y%m%d_%H%M)"
timestamp_human="$(date '+%Y-%m-%d %H:%M')"
level_upper="$(printf '%s' "${level}" | tr '[:lower:]' '[:upper:]')"
report_path="${output_dir}/WATCHDOG_${timestamp_file}_${level_upper}.md"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Never let a single non-zero exit code abort the whole run: any external
# command that can legitimately fail (flutter analyze on issues found, a
# missing remote-tracking ref, ...) is captured through this helper instead
# of being allowed to trip `set -e`.
run_capture() {
  local output
  set +e
  output="$("$@" 2>&1)"
  set -e
  printf '%s' "${output}"
}

alerts=()
add_alert() { alerts+=("$1"); }

# Highest-priority signal among those actually evaluated, per the ordering
# defined in 99_AI/MOBSANTE_WATCHDOG.md (RED > ORANGE > YELLOW > UNKNOWN >
# GREEN). REQUIRES_AI_REVIEW is treated like UNKNOWN for this ordering: it
# never masks a worse mechanical finding and never counts as GREEN.
compute_global() {
  local candidate signal
  for candidate in RED ORANGE YELLOW UNKNOWN REQUIRES_AI_REVIEW GREEN; do
    for signal in "$@"; do
      if [[ "${signal}" == "${candidate}" ]]; then
        if [[ "${candidate}" == "REQUIRES_AI_REVIEW" ]]; then
          printf 'UNKNOWN'
        else
          printf '%s' "${candidate}"
        fi
        return 0
      fi
    done
  done
  printf 'UNKNOWN'
}

# ---------------------------------------------------------------------------
# Git — LIGHT and above
# ---------------------------------------------------------------------------

git_branch="$(git branch --show-current 2>/dev/null || true)"
[[ -n "${git_branch}" ]] || git_branch="(detached HEAD)"

git_status_short="$(run_capture git status --short)"
git_status_line_count="$(printf '%s\n' "${git_status_short}" | grep -c . || true)"
git_conflict_count="$(printf '%s\n' "${git_status_short}" | grep -cE '^(UU|AA|DD) ' || true)"

git_divergence_known="false"
git_ahead_remote=0
git_ahead_local=0
if git rev-parse --verify --quiet origin/main >/dev/null 2>&1; then
  divergence_raw="$(run_capture git rev-list --left-right --count origin/main...HEAD)"
  if [[ "${divergence_raw}" =~ ^([0-9]+)[[:space:]]+([0-9]+)$ ]]; then
    git_ahead_remote="${BASH_REMATCH[1]}" # commits only on origin/main
    git_ahead_local="${BASH_REMATCH[2]}"  # commits only on local HEAD
    git_divergence_known="true"
  fi
fi

git_signal="GREEN"
if [[ "${git_conflict_count}" -gt 0 ]]; then
  git_signal="RED"
  git_summary="Marqueurs de conflit détectés dans git status (${git_conflict_count})."
elif [[ "${git_status_line_count}" -gt 0 && "${git_divergence_known}" == "true" && "${git_ahead_remote}" -gt 0 ]]; then
  git_signal="ORANGE"
  git_summary="Worktree non propre (${git_status_line_count} entrée(s)) et ${git_ahead_remote} commit(s) distants non fusionnés localement."
elif [[ "${git_status_line_count}" -gt 0 ]]; then
  git_signal="YELLOW"
  git_summary="Worktree non propre : ${git_status_line_count} entrée(s) modifiée(s)/non suivie(s)."
elif [[ "${git_divergence_known}" != "true" ]]; then
  git_signal="UNKNOWN"
  git_summary="Aucune référence locale origin/main connue pour évaluer la divergence."
else
  git_summary="Worktree propre, aucune divergence locale connue avec origin/main."
fi

if [[ "${git_divergence_known}" == "true" ]]; then
  add_alert "[INFO] Fraîcheur de origin/main non garantie sans fetch — état local connu : ${git_ahead_remote} commit(s) distant(s) non fusionnés, ${git_ahead_local} commit(s) local(aux) non poussés — Confiance: LOW (référence locale uniquement, aucun accès réseau exécuté) — vérifier manuellement (git fetch) si une décision de publication en dépend."
else
  add_alert "[UNKNOWN] Fraîcheur de origin/main non garantie sans fetch — aucune référence locale connue — Confiance: LOW — REQUIRES_AI_REVIEW ou git fetch manuel avant toute décision de publication."
fi

# ---------------------------------------------------------------------------
# JOB System — LIGHT and above
# ---------------------------------------------------------------------------

# The Control Plane and JOB Queue live in the Obsidian vault, which is a
# separate directory from this Git repository. Default matches this
# project's known local vault location; override with MOBSANTE_VAULT_DIR if
# the vault is mounted elsewhere.
default_vault_dir="/Users/marco/Library/Mobile Documents/com~apple~CloudDocs/Obsidian/PROJETS_IA/Mobilisation Santé/Mobilisation Santé"
vault_dir="${MOBSANTE_VAULT_DIR:-${default_vault_dir}}"
control_plane_path="${vault_dir}/99_AI/MOBSANTE_AI_CONTROL_PLANE.md"
job_queue_path="${vault_dir}/99_AI/MOBSANTE_JOB_QUEUE.md"

job_system_signal="UNKNOWN"
job_system_summary="Control Plane et/ou JOB Queue introuvables (vault attendu : ${vault_dir} — surchargeable via la variable MOBSANTE_VAULT_DIR)."
a_classer_snippet=""

if [[ -f "${control_plane_path}" && -f "${job_queue_path}" ]]; then
  cp_jobs="$(grep -oE 'JOB-[0-9]{4}' "${control_plane_path}" | sort -u || true)"
  jq_jobs="$(grep -oE 'JOB-[0-9]{4}' "${job_queue_path}" | sort -u || true)"
  cp_only="$(comm -23 <(printf '%s\n' "${cp_jobs}") <(printf '%s\n' "${jq_jobs}") 2>/dev/null | grep -v '^$' || true)"
  jq_only="$(comm -13 <(printf '%s\n' "${cp_jobs}") <(printf '%s\n' "${jq_jobs}") 2>/dev/null | grep -v '^$' || true)"

  if [[ -z "${cp_only}" && -z "${jq_only}" ]]; then
    job_system_signal="GREEN"
    job_system_summary="Mêmes identifiants JOB référencés dans le Control Plane et la JOB Queue (comparaison structurelle des identifiants uniquement, pas une vérification sémantique)."
  else
    job_system_signal="YELLOW"
    job_system_summary="Identifiants JOB non identiques entre Control Plane et JOB Queue (comparaison structurelle uniquement)."
    if [[ -n "${cp_only}" ]]; then
      add_alert "[YELLOW] JOB(s) référencé(s) dans le Control Plane mais absent(s) de la JOB Queue : $(printf '%s' "${cp_only}" | tr '\n' ' ') — Confiance: MEDIUM (comparaison structurelle des identifiants) — REQUIRES_AI_REVIEW pour confirmer s'il s'agit d'un réel écart."
    fi
    if [[ -n "${jq_only}" ]]; then
      add_alert "[YELLOW] JOB(s) référencé(s) dans la JOB Queue mais absent(s) du Control Plane : $(printf '%s' "${jq_only}" | tr '\n' ' ') — Confiance: MEDIUM (comparaison structurelle des identifiants) — REQUIRES_AI_REVIEW pour confirmer s'il s'agit d'un réel écart."
    fi
  fi

  a_classer_snippet="$(grep -c 'À CLASSER' "${control_plane_path}" || true)"
  job_system_summary="${job_system_summary} Occurrences « À CLASSER » dans le Control Plane : ${a_classer_snippet}."
fi

add_alert "[INFO] Rattachement changement local ↔ JOB non automatisé par ce script — nécessite les niveaux de preuve PROVEN/PROBABLE/UNKNOWN de 99_AI/MOBSANTE_WATCHDOG.md — Confiance: n/a — REQUIRES_AI_REVIEW pour toute conclusion d'attribution."

# ---------------------------------------------------------------------------
# Flutter — STANDARD and above
# ---------------------------------------------------------------------------

flutter_signal="UNKNOWN"
flutter_summary="Non évalué au niveau ${level} (Flutter n'est vérifié qu'à partir de STANDARD)."
flutter_output=""

if [[ "${level}" != "light" ]]; then
  if command -v flutter >/dev/null 2>&1; then
    flutter_output="$(run_capture flutter analyze)"
    if printf '%s' "${flutter_output}" | grep -q "No issues found!"; then
      flutter_signal="GREEN"
      flutter_summary="flutter analyze : aucun problème signalé."
    else
      flutter_signal="ORANGE"
      issue_lines="$(printf '%s' "${flutter_output}" | grep -cE '•' || true)"
      flutter_summary="flutter analyze a signalé des éléments (${issue_lines} ligne(s) avec « • ») — voir sortie détaillée dans ce rapport."
    fi
  else
    flutter_signal="UNKNOWN"
    flutter_summary="Commande flutter indisponible dans cet environnement."
  fi
fi

# ---------------------------------------------------------------------------
# Firebase — STANDARD and above (local, read-only)
# ---------------------------------------------------------------------------

firebase_signal="UNKNOWN"
firebase_summary="Non évalué au niveau ${level}."

if [[ "${level}" != "light" ]]; then
  firebase_modified="$(printf '%s\n' "${git_status_short}" | grep -E ' (firestore\.rules|firebase\.json|functions/)' || true)"
  firebase_modified_count="$(printf '%s\n' "${firebase_modified}" | grep -c . || true)"
  if [[ "${firebase_modified_count}" -gt 0 ]]; then
    firebase_signal="YELLOW"
    firebase_summary="${firebase_modified_count} fichier(s) Firebase/Rules/Functions modifié(s) localement, non publiés."
  elif [[ -f firebase.json ]]; then
    firebase_signal="GREEN"
    firebase_summary="firebase.json présent, aucun fichier Firebase/Rules/Functions modifié localement."
  else
    firebase_signal="UNKNOWN"
    firebase_summary="firebase.json introuvable."
  fi
fi

# ---------------------------------------------------------------------------
# Netlify — STANDARD and above (local, read-only)
# ---------------------------------------------------------------------------

netlify_signal="UNKNOWN"
netlify_summary="Non évalué au niveau ${level}."

if [[ "${level}" != "light" ]]; then
  if [[ -f netlify.toml ]]; then
    if grep -q '^\[build\]' netlify.toml; then
      netlify_signal="GREEN"
      netlify_summary="netlify.toml présent avec une section [build] détectée."
    else
      netlify_signal="YELLOW"
      netlify_summary="netlify.toml présent mais aucune section [build] détectée."
    fi
  else
    netlify_signal="UNKNOWN"
    netlify_summary="netlify.toml introuvable."
  fi
  add_alert "[UNKNOWN] État réel du dernier déploiement/build Netlify non vérifiable sans accès réseau — Confiance: n/a — vérifier manuellement le dashboard Netlify si un état à jour est nécessaire."
fi

# ---------------------------------------------------------------------------
# DEEP — preparation only, no extra command executed
# ---------------------------------------------------------------------------

if [[ "${level}" == "deep" ]]; then
  add_alert "[INFO] Niveau DEEP demandé : aucune suite de tests supplémentaire n'a été lancée automatiquement (règle du script) — Confiance: n/a — autoriser explicitement les vérifications DEEP recommandées par 99_AI/MOBSANTE_WATCHDOG.md (tests ciblés, contrôle renforcé) avant de les exécuter."
fi

# ---------------------------------------------------------------------------
# Global signal
# ---------------------------------------------------------------------------

evaluated_signals=("${git_signal}" "${job_system_signal}")
if [[ "${level}" != "light" ]]; then
  evaluated_signals+=("${flutter_signal}" "${firebase_signal}" "${netlify_signal}")
fi
global_signal="$(compute_global "${evaluated_signals[@]}")"

# ---------------------------------------------------------------------------
# Next Action (single, best-effort — never invents a semantic conclusion)
# ---------------------------------------------------------------------------

next_action="Aucune action requise."
if [[ ${#alerts[@]} -gt 0 || "${global_signal}" != "GREEN" ]]; then
  next_action="Revue humaine ou par un agent IA recommandée (REQUIRES_AI_REVIEW) — consulter la section Alertes de ce rapport avant toute décision."
fi

# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

{
  printf '# MobSanté Watchdog — %s\n\n' "${timestamp_human}"
  printf 'Niveau : %s. Généré automatiquement par `scripts/watchdog.sh` — voir `99_AI/MOBSANTE_WATCHDOG.md` pour le standard complet.\n\n' "${level_upper}"
  printf '**Avertissement** : ce rapport est produit par un script shell mécanique, sans jugement sémantique. Toute conclusion marquée `REQUIRES_AI_REVIEW` n'"'"'est pas un verdict et doit être traitée par une revue humaine ou par un agent IA, conformément à `99_AI/MOBSANTE_WATCHDOG.md` → « Règles de rattachement changement ↔ JOB ».\n\n'
  printf '## Global\n\n**%s**\n\n' "${global_signal}"

  printf '## Git\n\n**%s**\n\nRésumé : %s\n\n' "${git_signal}" "${git_summary}"
  printf -- '- Branche courante : `%s`\n' "${git_branch}"
  printf -- '- `git status --short` : %s entrée(s)\n' "${git_status_line_count}"
  printf -- '- Conflits détectés : %s\n' "${git_conflict_count}"
  if [[ "${git_divergence_known}" == "true" ]]; then
    printf -- '- Divergence locale connue avec `origin/main` : %s commit(s) distant(s) non fusionnés, %s commit(s) local(aux) non poussés (fraîcheur non garantie sans fetch)\n' "${git_ahead_remote}" "${git_ahead_local}"
  else
    printf -- '- Divergence avec `origin/main` : aucune référence locale connue\n'
  fi
  printf '\n'

  printf '## JOB System\n\n**%s**\n\nRésumé : %s\n\n' "${job_system_signal}" "${job_system_summary}"

  printf '## Flutter\n\n**%s**\n\nRésumé : %s\n\n' "${flutter_signal}" "${flutter_summary}"

  printf '## Firebase\n\n**%s**\n\nRésumé : %s\n\n' "${firebase_signal}" "${firebase_summary}"

  printf '## Netlify\n\n**%s**\n\nRésumé : %s\n\n' "${netlify_signal}" "${netlify_summary}"

  printf '## Alertes\n\n'
  if [[ ${#alerts[@]} -eq 0 ]]; then
    printf 'Aucune alerte.\n\n'
  else
    alert_count=0
    for alert in "${alerts[@]}"; do
      alert_count=$((alert_count + 1))
      if [[ ${alert_count} -gt 10 ]]; then
        printf -- '- (%d alerte(s) supplémentaire(s) tronquée(s) — maximum 10 par standard)\n' "$((${#alerts[@]} - 10))"
        break
      fi
      printf -- '- %s\n' "${alert}"
    done
    printf '\n'
  fi

  printf '## Next Action\n\n%s\n\n' "${next_action}"

  if [[ "${level}" != "light" && -n "${flutter_output}" && "${flutter_signal}" != "GREEN" ]]; then
    printf -- '---\n\n## Annexe — sortie brute `flutter analyze`\n\n```text\n%s\n```\n' "${flutter_output}"
  fi
} > "${report_path}"

echo "Watchdog (${level}) terminé. Rapport : ${report_path}"
echo "Global: ${global_signal}"
