#!/bin/bash
# A headless build of the plotting engine on FPC/Linux. The engine needs no
# display: with -dNOFORMS the base Thread does not pull in Forms, and with
# -dNOGRAPHICS BlobManager does not pull in Graphics. No widgetset, no display,
# just the computation.
#
# Environment (all optional):
#   FPC_ENV     a file that puts the right fpc on PATH
#   PARSER_SRC  the parser folder, if the guess is wrong
#   PARSER_JIT  the accelerator folder, if the guess is wrong
#   GRAPH_SRC   the plotting engine folder, if the guess is wrong

set -u
[ -n "${FPC_ENV:-}" ] && [ -f "${FPC_ENV}" ] && source "${FPC_ENV}"

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(dirname "$HERE")

GRAPH=${GRAPH_SRC:-$(cd "$ROOT/src" && pwd)}
if [ -n "${PARSER_SRC:-}" ]; then SRC=$PARSER_SRC
else SRC=$(cd "$ROOT/../pascal-mathparser/src" && pwd); fi
if [ -n "${PARSER_JIT:-}" ]; then JIT=$PARSER_JIT
else JIT=$(cd "$ROOT/../pascal-mathparser/jit" && pwd); fi

OUT=$HERE/out/fpc-linux
mkdir -p "$OUT"
cd "$HERE"

# The engine builds with the stable compiler. It used to need 3.3.1 for two
# reasons: CrossVision.Geometry sorted points with an anonymous comparer, and
# function references arrived in 3.3.1; and CrossGraph.Engine counted compiled
# scripts with AtomicIncrement, which 3.2.2 does not have. The sort now goes
# through the index callbacks the rest of the project uses, the counters through
# InterlockedIncrement, and the version gate that stood here is gone.
echo "Free Pascal $(fpc -iV 2>/dev/null)"

TARGETS="${@:-EngineTests EngineStress}"
FAILED=0
for T in $TARGETS; do
  echo "=== BUILD $T ==="
  rm -f "$OUT/$T"
  fpc -MDelphi -Sh -O2 -dNOFORMS -dNOGRAPHICS -B \
      -Fu"$SRC/compat" -Fu"$SRC" -Fu"$JIT" -Fu"$GRAPH" \
      -Fi"$SRC" -FU"$OUT" -FE"$OUT" "$T.dpr" 2>&1 \
    | grep -E 'Error:|Fatal:' | head -12
  if [ ! -x "$OUT/$T" ]; then echo "BUILD FAILED: $T"; FAILED=$((FAILED+1)); continue; fi
  echo "=== RUN $T ==="
  "$OUT/$T"; CODE=$?
  echo "code=$CODE"
  [ $CODE -ne 0 ] && FAILED=$((FAILED+1))
done
echo "=== TOTAL: failures $FAILED ==="
exit $FAILED
