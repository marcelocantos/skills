#!/usr/bin/env bash
#
# Self-test for check-formula.py.
#
# Two things have to hold for that script to be worth running:
#
#   1. Fidelity -- it must model homebrew-releaser exactly. Proven by rendering
#      real projects and comparing against the formulae the generator actually
#      wrote into the tap. A byte for byte match is the only honest evidence
#      that a clean lint here means a clean formula there.
#   2. Detection -- it must actually fail on the offences it claims to catch.
#      Proven with a throwaway project whose fragments carry a known-bad PATH.
#
# Usage:  test-check-formula.sh
# Env:    TAP  path to a homebrew-tap checkout   (default ~/work/github.com/marcelocantos/homebrew-tap)
#         SRC  parent dir of the project checkouts (default ~/work/github.com/marcelocantos)

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
checker="${here}/check-formula.py"
tap="${TAP:-${HOME}/work/github.com/marcelocantos/homebrew-tap}"
src="${SRC:-${HOME}/work/github.com/marcelocantos}"

# One project per distinct formula shape: no includes at all, service plus
# caveats plus a multi-binary install, and dependencies plus a shell wrapper.
readonly FIDELITY_PROJECTS="tapper spyder vellum"

pass=0
fail=0

report() {
  if [[ "$1" == "ok" ]]; then
    pass=$((pass + 1))
    printf 'ok    %s\n' "$2"
  else
    fail=$((fail + 1))
    printf 'FAIL  %s\n' "$2"
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT

# ---- 1. fidelity -------------------------------------------------------
# Read the tap at origin/master rather than the working tree: a local clone
# that has not been pulled for a while is months of releases behind, and every
# fidelity case would then fail for a reason that has nothing to do with this
# script. Fall back to the working tree when there is no such ref.
tap_formula() {
  local name="$1" out="$2"
  if git -C "${tap}" show "origin/master:Formula/${name}.rb" > "${out}" 2>/dev/null; then
    return 0
  fi
  [[ -f "${tap}/Formula/${name}.rb" ]] || return 1
  cp "${tap}/Formula/${name}.rb" "${out}"
}

for name in ${FIDELITY_PROJECTS}; do
  formula="${tmp}/shipped-${name}.rb"
  project="${src}/${name}"
  if [[ ! -d "${project}" ]] || ! tap_formula "${name}" "${formula}"; then
    printf 'skip  fidelity %s (no checkout, or no formula in the tap)\n' "${name}"
    continue
  fi
  rendered="${tmp}/${name}.rb"
  python3 "${checker}" "${project}" --emit --from-formula "${formula}" > "${rendered}"
  if diff -u "${formula}" "${rendered}" > "${tmp}/${name}.diff"; then
    report ok "fidelity ${name}: render matches the generated formula"
  else
    report fail "fidelity ${name}: render drifted from the generated formula"
    echo "      either the model is stale, or ${name}'s fragments changed since"
    echo "      its last release. The diff says which:"
    sed 's/^/      /' "${tmp}/${name}.diff"
  fi
done

# ---- 2. detection ------------------------------------------------------
scenario() {
  local label="$1" want="$2" includes="$3"
  local dir="${tmp}/${label}"
  mkdir -p "${dir}/tapper"
  git -C "${dir}" init -q 2>/dev/null || true
  cat > "${dir}/tapper.yaml" <<YAML
repo: example/${label}
tap:
  owner: example
  name: homebrew-tap
test: 'system bin/"${label}", "--version"'
install_file: tapper/install.rb
formula_includes_file: tapper/formula_includes.rb
YAML
  printf 'bin.install "%s"\n' "${label}" > "${dir}/tapper/install.rb"
  printf '%s\n' "${includes}" > "${dir}/tapper/formula_includes.rb"

  set +e
  python3 "${checker}" "${dir}" > "${dir}/out.txt" 2>&1
  local got=$?
  set -e
  if [[ "${got}" -eq "${want}" ]]; then
    report ok "detection ${label}: exit ${got} as expected"
  else
    report fail "detection ${label}: exit ${got}, wanted ${want}"
    sed 's/^/      /' "${dir}/out.txt"
  fi
}

scenario hardcodedprefix 1 'service do
  run [opt_bin/"hardcodedprefix"]
  environment_variables PATH: "/opt/homebrew/bin:#{ENV["HOME"]}/.py/bin:/usr/bin:/bin"
end'

scenario cleanservice 0 'service do
  run [opt_bin/"cleanservice"]
  keep_alive true
  environment_variables PATH: std_service_path_env
end'

scenario noincludes 0 ''

printf '\n%d passed, %d failed\n' "${pass}" "${fail}"
[[ ${fail} -eq 0 ]]
