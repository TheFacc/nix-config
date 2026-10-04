# Sync preflight for files whose creators explicitly restricted inherited modes.
set -euo pipefail

directory=${1:?Hermes directory required}
vault_group=${2:?vault group required}
[[ -d "$directory" ]] || exit 0
if [[ -L "$directory" ]]; then
  printf 'Refusing group permission repair on a symlink: %s\n' "$directory" >&2
  exit 1
fi

# Do not follow symlinks, including arguments replaced during the walk. Mode group
# bits show the ACL mask, so only entries whose mask lost group access are touched.
# Run every pass even if one fails (e.g. a file vanished), then report failure.
rc=0
find -P "$directory" ! -type l ! -group "$vault_group" \
  -execdir chgrp -h "$vault_group" -- {} + || rc=1
find -P "$directory" -type d ! -perm -g=rwx \
  -execdir setfacl -P -m g::rwx,m::rwx -- {} + || rc=1
find -P "$directory" -type f ! -perm /111 ! -perm -g=rw \
  -execdir setfacl -P -m g::rw,m::rw -- {} + || rc=1
find -P "$directory" -type f -perm /111 ! -perm -g=rwx \
  -execdir setfacl -P -m g::rwx,m::rwx -- {} + || rc=1
exit "$rc"
