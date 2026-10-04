# Called by hermes-vault-acl; dependencies are supplied by writeShellApplication.
set -euo pipefail

vault=${1:?vault directory required}
acl_user=${2:?Hermes user required}
shift 2

# Validate the configured roots before a privileged walk. Child symlinks are
# skipped by find -P and setfacl -P, including symlink arguments swapped in later.
trees=("$vault")
writable_exclusions=()
for directory in "$@"; do
  trees+=("$vault/$directory")
  writable_exclusions+=(-path "$vault/$directory" -prune -o)
done
for tree in "${trees[@]}"; do
  if [[ ! -d "$tree" || -L "$tree" ]]; then
    printf 'Refusing ACL setup on a missing directory or symlink: %s\n' "$tree" >&2
    exit 1
  fi
done

# Run every pass even if one fails (e.g. a file vanished), then report failure.
rc=0
apply_tree() {
  local tree=$1 permissions=$2
  local -a exclusions=()
  if [[ "$tree" == "$vault" ]]; then
    # Keep writable subtrees writable while refreshing the rest of the vault.
    exclusions=("${writable_exclusions[@]}")
  fi
  find -P "$tree" "${exclusions[@]}" -type d -execdir setfacl -P -m \
    "u:$acl_user:${permissions}x,d:u:$acl_user:${permissions}x,g::rwx,d:g::rwx,m::rwx,d:m::rwx" -- {} + || rc=1

  # Test the effective mode BEFORE changing the mask. Conditional X consults
  # raw ACL entries too, and can expose execute bits inherited by ordinary notes.
  find -P "$tree" "${exclusions[@]}" -type f ! -perm /111 -execdir setfacl -P -m \
    "u:$acl_user:$permissions,g::rw,m::rw" -- {} + || rc=1
  find -P "$tree" "${exclusions[@]}" -type f -perm /111 -execdir setfacl -P -m \
    "u:$acl_user:${permissions}x,g::rwx,m::rwx" -- {} + || rc=1
}

apply_tree "$vault" r
for directory in "$@"; do
  apply_tree "$vault/$directory" rw
done
exit "$rc"
