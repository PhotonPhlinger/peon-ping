#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  EMIT_SH="${PEON_SH%/peon.sh}/adapters/emit.sh"

  # Adapter resolves peon.sh via CLAUDE_PEON_DIR
  ln -sf "$PEON_SH" "$TEST_DIR/peon.sh"
}

teardown() {
  teardown_test_env
}

run_emit() {
  export PEON_TEST=1
  bash "$EMIT_SH" "$@" 2>"$TEST_DIR/stderr.log"
  EMIT_EXIT=$?
  EMIT_STDERR=$(cat "$TEST_DIR/stderr.log" 2>/dev/null)
  sleep 0.3
}

@test "adapter script has valid bash syntax" {
  run bash -n "$EMIT_SH"
  [ "$status" -eq 0 ]
}

@test "session.start plays greeting" {
  run_emit session.start --session-id e1
  [ "$EMIT_EXIT" -eq 0 ]
  afplay_was_called
  [[ "$(afplay_sound)" == *"/packs/peon/sounds/Hello"* ]]
}

@test "task.complete plays completion sound" {
  run_emit task.complete --session-id e1 --message "all done"
  [ "$EMIT_EXIT" -eq 0 ]
  afplay_was_called
  [[ "$(afplay_sound)" == *"/packs/peon/sounds/Done"* ]]
}

@test "input.required plays permission sound" {
  run_emit input.required --session-id e1 --message Bash
  [ "$EMIT_EXIT" -eq 0 ]
  afplay_was_called
  [[ "$(afplay_sound)" == *"/packs/peon/sounds/Perm"* ]]
}

@test "resource.limit plays limit sound" {
  run_emit resource.limit --session-id e1
  [ "$EMIT_EXIT" -eq 0 ]
  afplay_was_called
  [[ "$(afplay_sound)" == *"/packs/peon/sounds/Limit"* ]]
}

@test "task.error plays error sound" {
  run_emit task.error --session-id e1 --message "exit 1"
  [ "$EMIT_EXIT" -eq 0 ]
  afplay_was_called
  [[ "$(afplay_sound)" == *"/packs/peon/sounds/Error"* ]]
}

@test "unknown category exits 2 with a usage hint and plays nothing" {
  export PEON_TEST=1
  run bash "$EMIT_SH" not.a.category
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown category"* ]]
  ! afplay_was_called
}

@test "resolves peon.sh from its own install folder without CLAUDE_PEON_DIR" {
  mkdir -p "$TEST_DIR/portable/adapters"
  cp "$EMIT_SH" "$TEST_DIR/portable/adapters/emit.sh"
  printf '#!/bin/bash\ncat > "%s/portable/received.json"\n' "$TEST_DIR" > "$TEST_DIR/portable/peon.sh"
  unset CLAUDE_PEON_DIR
  bash "$TEST_DIR/portable/adapters/emit.sh" task.complete --session-id p1
  grep -q '"hook_event_name": "Stop"' "$TEST_DIR/portable/received.json"
  grep -q '"session_id": "p1"' "$TEST_DIR/portable/received.json"
}
