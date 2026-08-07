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

# Function references arrived in Free Pascal 3.3.1, and the engine needs them:
# CrossVision.Geometry sorts points with an anonymous comparer. On 3.2.2 the
# build stops with a syntax error in the middle of that file - a refusal that
# reads like a broken source rather than a missing feature. Say so instead.
#
# Exit code zero: an unsuitable compiler is not a failed build. But not silence
# either - the line below is always printed.
VER=$(fpc -iV 2>/dev/null)
MAJOR=${VER%%.*}
REST=${VER#*.}
MINOR=${REST%%.*}
if [ "${MAJOR:-0}" -lt 3 ] || { [ "${MAJOR:-0}" -eq 3 ] && [ "${MINOR:-0}" -lt 3 ]; }; then
  echo "SKIPPED: the plotting engine needs Free Pascal 3.3.1 or newer (function"
  echo "         references in CrossVision.Geometry), this is $VER"
  exit 0
fi

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
