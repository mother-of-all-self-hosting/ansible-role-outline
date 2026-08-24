#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Slavi Pantaleev
#
# SPDX-License-Identifier: AGPL-3.0-or-later

# Tests bin/compute-next-tag.sh against throwaway git repositories.
#
# Usage: bin/test-compute-next-tag.sh
#
# Every scenario builds its own repository under a temporary directory, replays
# a sequence of commits through the real script and tags as it goes, exactly as
# the autotag workflow would. Nothing reaches the network.
#
# Every repository this script builds is marked with a sentinel file, and both
# committing and tagging refuse to touch a working directory that lacks it.
# Without that guard a scenario helper that failed to change directory would
# quietly commit its fixtures into the repository being tested, which is a
# mistake worth making impossible rather than merely unlikely.

set -uo pipefail

script_path="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/compute-next-tag.sh"

sentinel='.throwaway-test-repository'

failures=0
created_directories=()

ok() {
	echo "ok - $1"
}

fail() {
	echo "FAIL - $1"
	echo "    expected: '$2'"
	echo "    actual:   '$3'"
	failures=$((failures + 1))
}

check() {
	local description="$1" expected="$2" actual="$3"
	if [ "$expected" = "$actual" ]; then
		ok "$description"
	else
		fail "$description" "$expected" "$actual"
	fi
}

# Refuses to go on unless the current directory is one of the throwaway
# repositories built below.
require_throwaway() {
	if [ ! -e "$sentinel" ]; then
		echo >&2 "Refusing to $1 in $(pwd): not a throwaway test repository"
		exit 1
	fi
}

commit_all() {
	require_throwaway 'commit'
	git add -A
	git commit -q -m "$1"
}

tag_as() {
	require_throwaway 'tag'
	git tag "$1"
}

# A defaults/main.yml shaped like the real one: the version that gets released
# sits among decoy keys that also mention a version, one of which even derives
# itself from `outline_version`. Anchoring on `^outline_version:` is what keeps
# those out of the answer.
write_defaults() {
	mkdir -p defaults
	cat > defaults/main.yml <<EOF
---
outline_enabled: true

outline_identifier: outline

# renovate: datasource=docker depName=outlinewiki/outline versioning=semver
outline_version: $1

outline_container_image_tag: "{{ outline_version }}"
outline_container_image_self_build_repo_version: "{{ 'v' + outline_version if outline_version != 'latest' else 'main' }}"
EOF
}

# Builds a repository seeded at 1.9.2 with releases -0 and -1 already cut, and
# changes into it. Runs in this shell on purpose: a subshell would leave the
# caller in whatever directory it was already in.
start_scenario() {
	local directory
	directory="$(mktemp -d)"
	created_directories+=("$directory")

	cd -- "$directory" || exit 1
	touch "$sentinel"

	git init -q -b main .
	git config user.name 'Test'
	git config user.email 'test@example.com'

	mkdir -p tasks templates meta molecule/default .github/workflows bin
	install -m 0755 "$script_path" bin/compute-next-tag.sh
	write_defaults 1.9.2
	echo 'tasks' > tasks/main.yml
	echo 'templates' > templates/env.j2
	echo 'meta' > meta/main.yml
	echo 'readme' > README.md
	echo 'molecule' > molecule/default/verify.yml
	commit_all 'Initial'
	tag_as v1.9.2-0

	echo 'tasks changed' > tasks/main.yml
	commit_all 'A role change'
	tag_as v1.9.2-1
}

cleanup() {
	cd / || true
	local directory
	for directory in ${created_directories+"${created_directories[@]}"}; do
		case "$directory" in
			/tmp/*|/var/folders/*) rm -rf -- "$directory" ;;
		esac
	done
}
trap cleanup EXIT

# The script resolves the repository to work on from its own location, not from
# the working directory, so each scenario runs the copy that start_scenario
# placed inside it. Invoking "$script_path" directly would compute a tag for
# the repository this test lives in.
compute() {
	require_throwaway 'compute a tag'
	./bin/compute-next-tag.sh 2>/dev/null
}

# --- A version bump merged before other role changes ------------------------

start_scenario
write_defaults 1.9.3
commit_all 'Update outlinewiki/outline Docker tag to v1.9.3'
check 'a never-released version restarts the counter at 0' 'v1.9.3-0' "$(compute)"
tag_as v1.9.3-0

echo 'more tasks' > tasks/main.yml
commit_all 'Another role change'
check 'a role change after a release increments the counter' 'v1.9.3-1' "$(compute)"
tag_as v1.9.3-1

echo 'more templates' > templates/env.j2
commit_all 'A template change'
check 'a second role change increments again' 'v1.9.3-2' "$(compute)"

# --- A version bump merged after other role changes -------------------------

start_scenario
echo 'unreleased work' > tasks/main.yml
commit_all 'A role change landing before the version bump'
check 'a role change on the old version increments the old counter' 'v1.9.2-2' "$(compute)"
tag_as v1.9.2-2

write_defaults 1.9.3
commit_all 'Update outlinewiki/outline Docker tag to v1.9.3'
check 'the version bump then restarts at 0 regardless of merge order' 'v1.9.3-0' "$(compute)"

# --- Commits that do not affect the role ------------------------------------

start_scenario
echo 'a documentation fix' > README.md
commit_all 'Update README.md'
check 'a README change warrants no release' '' "$(compute)"

mkdir -p molecule/oidc
echo 'a new scenario' > molecule/oidc/verify.yml
commit_all 'Add a Molecule scenario'
check 'a Molecule change warrants no release' '' "$(compute)"

echo 'workflow' > .github/workflows/molecule.yml
commit_all 'Update the Molecule workflow'
check 'a CI change warrants no release' '' "$(compute)"

echo 'tasks again' > tasks/main.yml
commit_all 'A role change after all that'
check 'a later role change still releases, counting from the last release' 'v1.9.2-2' "$(compute)"

# --- Release numbers past 9 -------------------------------------------------

start_scenario
for release in 2 3 4 5 6 7 8 9 10; do
	tag_as "v1.9.2-${release}"
done
echo 'past nine' > tasks/main.yml
commit_all 'A role change with double-digit releases around'
check 'release numbers are sorted numerically, not lexically' 'v1.9.2-11' "$(compute)"

# --- Reverting to an already released state ---------------------------------

# Reverting is measured against the last release, not against the history. A
# change that lands and is then taken back leaves the role exactly as v1.9.2-1
# published it, so there is nothing to release - whereas reverting to some
# older release would be a change that consumers pinned to v1.9.2-1 do need.
start_scenario
echo 'a change that will be taken back' > tasks/main.yml
commit_all 'Change the role'
check 'the change on its own would release' 'v1.9.2-2' "$(compute)"

echo 'tasks changed' > tasks/main.yml
commit_all 'Revert the role change'
check 'taking it back again warrants no release' '' "$(compute)"

echo 'tasks' > tasks/main.yml
commit_all 'Go back to what v1.9.2-0 published'
check 'reverting past the last release is itself a change worth releasing' 'v1.9.2-2' "$(compute)"

# --- Adversarial defaults/main.yml shapes -----------------------------------

start_scenario
write_defaults '"1.9.4"'
commit_all 'Quote the version'
check 'a quoted version is unquoted for the tag' 'v1.9.4-0' "$(compute)"

start_scenario
write_defaults 'v1.9.5'
commit_all 'Give the version a leading v'
check 'a version already carrying a leading v does not double it' 'v1.9.5-0' "$(compute)"

start_scenario
# A decoy that mentions the key in a comment, a derived key that embeds it, and
# an inline comment on the real one.
cat > defaults/main.yml <<'EOF'
---
# outline_version: 9.9.9 (an old value, kept for reference)
outline_version: 1.9.6  # bumped by Renovate
outline_container_image_self_build_repo_version: "{{ 'v' + outline_version }}"
EOF
commit_all 'Surround the version with decoys'
check 'commented-out and derived keys are not mistaken for the version' 'v1.9.6-0' "$(compute)"

start_scenario
cat > defaults/main.yml <<'EOF'
---
outline_identifier: outline
EOF
commit_all 'Remove the version entirely'
./bin/compute-next-tag.sh >/dev/null 2>&1
check 'a defaults file with no version fails loudly' '1' "$?"

# ---------------------------------------------------------------------------

if [ "$failures" -ne 0 ]; then
	echo
	echo "$failures check(s) failed"
	exit 1
fi

echo
echo 'All checks passed'
