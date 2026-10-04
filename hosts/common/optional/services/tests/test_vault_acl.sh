#!/usr/bin/env bash
# Run with bash; requires acl, findutils, and coreutils on PATH.
set -euo pipefail

setup_script=${1:-"$(dirname "$0")/../vault-acl.sh"}
group_script=${2:-"$(dirname "$0")/../vault-group-perms.sh"}
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT
acl_user=$(id -u)
vault="$test_dir/root/vault"
mkdir -p "$vault/Notes/Nested" "$vault/Hermes/Nested" "$test_dir/outside"
chmod 2770 "$vault" "$vault/Notes" "$vault/Notes/Nested" "$vault/Hermes" "$vault/Hermes/Nested"

assert_acl() {
  local path=$1 entry=$2 expected=$3 actual
  actual=$(getfacl -cpn "$path" | awk -v entry="$entry" 'index($0, entry ":") == 1 { print substr($0, length(entry) + 2) }')
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s %s: expected %s, got %s\n' "$path" "$entry" "$expected" "$actual" >&2
    exit 1
  fi
}

assert_mode() {
  local path=$1 expected=$2 actual
  actual=$(stat -c %a "$path")
  if [[ "$actual" != "$expected" ]]; then
    printf 'FAIL: %s: expected mode %s, got %s\n' "$path" "$expected" "$actual" >&2
    exit 1
  fi
}

apply_acls() {
  bash "$setup_script" "$vault" "$acl_user" Hermes
}

# Reproduce existing tmpfiles defaults: raw execute bits masked off on notes.
setfacl -m "u:$acl_user:r-x,d:u:$acl_user:r-x,d:g::rwx,d:m::r-x" "$vault/Notes" "$vault/Notes/Nested"
touch "$vault/Notes/legacy.md" "$vault/Notes/Nested/legacy.md"
assert_mode "$vault/Notes/legacy.md" 640
touch "$vault/Notes/private.md" "$vault/Notes/executable" "$vault/Hermes/legacy.md"
chmod 0600 "$vault/Notes/private.md"
chmod 0750 "$vault/Notes/executable"

# A privileged ACL walk must leave symlink targets completely untouched.
touch "$test_dir/outside/note.md"
chmod 0600 "$test_dir/outside/note.md"
outside_acl=$(getfacl -cpn "$test_dir/outside/note.md")
ln -s "$test_dir/outside/note.md" "$vault/Hermes/link.md"
ln -s "$test_dir/outside" "$vault/Hermes/link-dir"

apply_acls
for note in "$vault/Notes/legacy.md" "$vault/Notes/Nested/legacy.md" "$vault/Notes/private.md"; do
  assert_mode "$note" 660
  assert_acl "$note" "user:$acl_user" r--
  assert_acl "$note" group: rw-
  assert_acl "$note" mask: rw-
done
assert_mode "$vault/Notes/executable" 770
assert_acl "$vault/Notes/executable" "user:$acl_user" r-x
assert_acl "$vault/Hermes/legacy.md" "user:$acl_user" rw-
[[ $(getfacl -cpn "$test_dir/outside/note.md") == "$outside_acl" ]]
printf 'PASS: migration, group writes, existing executables, and symlink targets\n'

# New files/subdirectories inherit permissions despite a restrictive umask.
(umask 077; touch "$vault/Notes/new.md" "$vault/Hermes/new.md"; mkdir "$vault/Notes/new-dir"; touch "$vault/Notes/new-dir/new.md")
for note in "$vault/Notes/new.md" "$vault/Notes/new-dir/new.md" "$vault/Hermes/new.md"; do
  assert_mode "$note" 660
done
assert_acl "$vault/Notes/new-dir" default:group: rwx
assert_acl "$vault/Notes/new-dir" default:mask: rwx
assert_acl "$vault/Notes/new-dir" "default:user:$acl_user" r-x
assert_acl "$vault/Hermes" "default:user:$acl_user" rwx
printf 'PASS: inherited group write and Hermes permissions\n'

# Tools can explicitly restrict the inherited mask. Sync must repair group
# writes without exposing the raw execute bits in Hermes' inherited user ACL.
touch "$vault/Hermes/private.md" "$vault/Hermes/executable"
chmod 0600 "$vault/Hermes/private.md"
chmod 0750 "$vault/Hermes/executable"
bash "$group_script" "$vault/Hermes" "$(id -gn)"
assert_mode "$vault/Hermes/private.md" 660
assert_acl "$vault/Hermes/private.md" group: rw-
assert_acl "$vault/Hermes/private.md" mask: rw-
assert_mode "$vault/Hermes/executable" 770
[[ $(getfacl -cpn "$test_dir/outside/note.md") == "$outside_acl" ]]
printf 'PASS: sync repairs restricted notes without adding execute permission\n'

for _ in 1 2; do
  apply_acls
  bash "$group_script" "$vault/Hermes" "$(id -gn)"
  for note in "$vault/Notes/new.md" "$vault/Notes/new-dir/new.md"; do
    assert_mode "$note" 660
    assert_acl "$note" "user:$acl_user" r--
  done
  assert_acl "$vault/Hermes/new.md" "user:$acl_user" rw-
  assert_mode "$vault/Hermes/private.md" 660
  assert_mode "$vault/Notes/executable" 770
done
printf 'PASS: repeated setup keeps notes non-executable and Hermes writes restricted\n'

# Refuse a symlink used as the writable subtree itself.
ln -s "$test_dir/outside" "$vault/Unsafe"
if bash "$setup_script" "$vault" "$acl_user" Unsafe; then
  printf 'FAIL: setup accepted a symlink as a writable directory\n' >&2
  exit 1
fi
[[ $(getfacl -cpn "$test_dir/outside/note.md") == "$outside_acl" ]]
printf 'PASS: writable subtree symlinks rejected\n'
