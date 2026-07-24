#!/usr/bin/env bash
# Runs every integration test headless and summarizes results.
# Usage: tests/run_all.sh [filter-substring]
# Exits nonzero if any test fails. mouse_look_test self-skips when no display is available.
set -u
cd "$(dirname "$0")/.." || exit 1
filter="${1:-}"
pass=0
fail=0
failed=()
for t in tests/integration/*_test.gd; do
	if [[ -n "$filter" && "$t" != *"$filter"* ]]; then
		continue
	fi
	log="/tmp/wizsim_$(basename "$t").log"
	if timeout 60 godot --headless --path . -s "$t" > "$log" 2>&1; then
		echo "PASS $t"
		((pass++))
	else
		rc=$?
		echo "FAIL(rc=$rc) $t"
		((fail++))
		failed+=("$t")
		grep -E '\[FAIL\]|SCRIPT ERROR' "$log" | sed 's/^/    /'
	fi
done
echo
echo "passed=$pass failed=$fail"
if ((fail > 0)); then
	printf 'failed: %s\n' "${failed[@]}"
	exit 1
fi
