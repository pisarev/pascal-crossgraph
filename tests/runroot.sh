# Run root OUTSIDE the tree under test. Sourced with the dot command.
#
# By default a build script writes next to itself, and a test run then changes
# the very tree it is checking. Measured on 2026-08-11 in the release
# candidate: 779 binary files, 47 of them executable, had settled inside the
# published tree because the gates compiled into it. A fingerprint that skips
# ignored paths cannot see that, so "the tree did not change" kept agreeing
# while the tree changed.
#
#     runroot_init <tree-directory>
#
# Sets RUNROOT. Takes it from the environment when set, otherwise makes a
# temporary one. Refuses when the run root is physically inside the tree.

runroot_init() {
    _rr_tree=$(cd "$1" && pwd -P) || {
        echo "REFUSED: tree root does not resolve: $1" >&2
        return 1
    }

    # ${RUNROOT:-}, not $RUNROOT: these scripts run under set -u, where reading
    # an unset variable kills the run on this very line, before the rule gets
    # to decide anything.
    if [ -n "${RUNROOT:-}" ]; then
        mkdir -p "$RUNROOT" || {
            echo "REFUSED: run root not created: $RUNROOT" >&2
            return 1
        }
        RUNROOT=$(cd "$RUNROOT" && pwd -P) || {
            echo "REFUSED: run root does not resolve: $RUNROOT" >&2
            return 1
        }
    else
        RUNROOT=$(mktemp -d) || {
            echo "REFUSED: temporary run root not created" >&2
            return 1
        }
    fi

    # Separation is checked PHYSICALLY, on resolved paths: a symbolic link and
    # a .. segment both lead back inside while the name still looks external.
    case "$RUNROOT/" in
        "$_rr_tree"/*)
            echo "REFUSED: run root is physically INSIDE the tree under test" >&2
            echo "  tree: $_rr_tree" >&2
            echo "  root: $RUNROOT" >&2
            return 1
            ;;
    esac

    echo "run root: $RUNROOT"
    return 0
}
