#!/usr/bin/env bash
set -eu
grep 'Found Windows update ' "$1" \
    | sed -E 's,\x1b[^m]+m,,g' \
    | sed -E 's,.+ Found Windows update \((.+?); .+\): (.+),  * \1: \2,g' \
    | sort \
    | uniq
