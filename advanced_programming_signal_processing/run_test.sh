#!/bin/sh
# make matcher  # ← 差分あればビルド、なければスキップ

INPUT_DIR="$1"
RESULT_DIR="result"
TEMPLATE_DIR="level7"

mkdir -p "$RESULT_DIR"

find "$INPUT_DIR" -name 'level7_???.ppm' | \
  xargs -n1 -P$(nproc) -I{} sh -c \
  './matcher "{}" '"$TEMPLATE_DIR"' > '"$RESULT_DIR"'/"$(basename "{}" .ppm).txt"'
