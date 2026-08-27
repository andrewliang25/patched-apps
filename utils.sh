#!/usr/bin/env bash

MODULE_TEMPLATE_DIR="module"
CWD=$(pwd)
TEMP_DIR="temp"
BIN_DIR="bin"
BUILD_DIR="build"
DL_SRCS=("direct" "archive" "apkmirror" "uptodown")
# For each app, the patch-bundle asset that the last successful build used. The file lives on
# the 'update' branch. config_update reads it, and build.yml adds to it.
PATCHES_STATE_FILE="patches-state.json"
# The part built in this run. build.sh writes it and build.yml merges it into PATCHES_STATE_FILE.
BUILT_PATCHES_FILE="patches-built.json"
# The enabled apps in this run that made no artifact, one "<table>\t<reason>" line each. build.sh
# prints a summary, and build.yml sends the list to the admin chat and the job summary. One failed
# app does not fail the job, because the other apps still ship. Without this file the failure is
# invisible.
FAILED_BUILDS_FILE="failed-builds.txt"
# The apps in this run that shipped with a warning, one "<table>\t<message>" line each. One
# example is an 'auto' build that stepped down below the latest supported version, because that
# version was not downloadable. build.yml sends these to the admin chat and the job summary.
BUILD_WARNINGS_FILE="build-warnings.txt"

if [ "${GITHUB_TOKEN-}" ]; then GH_HEADER="Authorization: token ${GITHUB_TOKEN}"; else GH_HEADER=; fi
NEXT_VER_CODE=${NEXT_VER_CODE:-$(date +'%Y%m%d')}
OS=$(uname -o)

toml_prep() {
	if [ ! -f "$1" ]; then return 1; fi
	if [ "${1##*.}" == toml ]; then
		__TOML__=$($TOML --output json --file "$1" .)
	elif [ "${1##*.}" == json ]; then
		__TOML__=$(cat "$1")
	else abort "config extension not supported"; fi
}
toml_get_table_names() { jq -r -e 'to_entries[] | select(.value | type == "object") | .key' <<<"$__TOML__"; }
toml_get_table_main() { jq -r -e 'to_entries | map(select(.value | type != "object")) | from_entries' <<<"$__TOML__"; }
toml_get_table() { jq -r -e ".\"${1}\"" <<<"$__TOML__"; }
# The *-update.json basename for a table name: lowercase, with '/' changed to '-'.
update_json_name() { local s=${1,,}; echo "${s//\//-}-update.json"; }
# The magisk module id for a table name: lowercase, with every character outside [a-z0-9._-]
# changed to '-'. This includes spaces, '/' and '+'. At flash time magisk tests the id against
# ^[a-zA-Z][a-zA-Z0-9._-]+$ and refuses the zip if the id does not match.
module_id_name() { local s=${1,,}; echo "${s//[!a-z0-9._-]/-}"; }
toml_get() {
	local op quote_placeholder=$'\001'
	op=$(jq -r ".\"${2}\" | values" <<<"$1")
	if [ "$op" ]; then
		op="${op#"${op%%[![:space:]]*}"}"
		op="${op%"${op##*[![:space:]]}"}"
		op=${op//\\\'/$quote_placeholder}
		op=${op//"''"/$quote_placeholder}
		op=${op//"'"/'"'}
		op=${op//$quote_placeholder/$'\''}
		echo "$op"
	else return 1; fi
}

pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }
epr() {
	echo >&2 -e "\033[0;31m[-] ${1}\033[0m"
	if [ "${GITHUB_REPOSITORY-}" ]; then echo >&2 -e "::error::utils.sh [-] ${1}\n"; fi
}
wpr() {
	echo >&2 -e "\033[0;33m[!] ${1}\033[0m"
	if [ "${GITHUB_REPOSITORY-}" ]; then echo >&2 -e "::warning::utils.sh [!] ${1}\n"; fi
}

_clean_tmp() {
	rm -rf ./${TEMP_DIR}/*tmp.* ./${TEMP_DIR}/*tmp_* ./${TEMP_DIR}/*/*tmp.* ./${TEMP_DIR}/*-temporary-files ./*-temporary-files
}

abort() {
	epr "ABORT: ${1-}"
	_clean_tmp
	trap - SIGTERM SIGINT EXIT
	kill -9 -- -$$ 2>/dev/null
	exit 1
}
java() {
	if [ "${JAVA_HOME_21_X64-}" ]; then
		env -i JAVA_HOME="$JAVA_HOME_21_X64" "$JAVA_HOME_21_X64"/bin/java --enable-native-access=ALL-UNNAMED "$@"
	else
		env -i java --enable-native-access=ALL-UNNAMED "$@"
	fi
}

get_prebuilts() {
	local cli_src=$1 cli_ver=$2 patches_src=$3 patches_ver=$4
	local patches_src_bare=$patches_src
	if [[ "$patches_src" == gitlab:* ]]; then patches_src_bare="${patches_src#gitlab:}"; fi
	pr "Getting prebuilts (${patches_src_bare%/*})" >&2
	# The changelog part for this source. build.sh puts it into build.md only if this bundle ships.
	local cl_file
	cl_file=$(cl_changelog_file "$patches_src")
	mkdir -p "$(dirname "$cl_file")"

	for src_ver in "$patches_src Patches $patches_ver" "$cli_src CLI $cli_ver"; do
		set -- $src_ver
		local src=$1 tag=$2 ver=${3-}

		local is_gitlab=false bare_src="$src"
		if [[ "$src" == gitlab:* ]]; then is_gitlab=true; bare_src="${src#gitlab:}"; fi

		if [ "$tag" = "CLI" ]; then
			local grab_cl=false
		elif [ "$tag" = "Patches" ]; then
			local grab_cl=true
		else abort unreachable; fi

		local dir=${bare_src%/*}
		dir=${TEMP_DIR}/${dir,,}-rv
		[ -d "$dir" ] || mkdir "$dir"

		local rv_rel name_ver
		if [ "$is_gitlab" = true ]; then
			rv_rel="https://gitlab.com/api/v4/projects/${bare_src//\//%2F}/releases"
		else
			rv_rel="https://api.github.com/repos/${bare_src}/releases"
		fi
		if [ "$ver" = "dev" ]; then
			local resp
			if [ "$is_gitlab" = true ]; then
				resp=$(req "$rv_rel" -) || return 1
			else
				resp=$(gh_req "$rv_rel" -) || return 1
			fi
			ver=$(jq -e -r '.[] | .tag_name' <<<"$resp" | get_highest_ver) || return 1
		fi
		if [ "$ver" = "latest" ]; then
			if [ "$is_gitlab" = false ]; then rv_rel+="/latest"; fi
			name_ver="*"
		else
			if [ "$is_gitlab" = true ]; then
				rv_rel+="/${ver}"
			else
				rv_rel+="/tags/${ver}"
			fi
			name_ver="$ver"
		fi

		local file
		if [ "$tag" = "CLI" ]; then
			file=$(find "$dir" -maxdepth 1 -name "*cli-${name_ver#v}*.jar" -o -name "*desktop-${name_ver#v}*.jar" -type f 2>/dev/null)
		elif [ "$tag" = "Patches" ]; then
			file=$(find "$dir" -maxdepth 1 -name "*patches-${name_ver#v}.*" -type f 2>/dev/null)
		else abort unreachable; fi

		local url tag_name matches
		if [ "$ver" = "latest" ]; then
			file=$(grep -v '/[^/]*dev[^/]*$' <<<"$file" | head -1)
		else
			file=$(grep "/[^/]*${ver#v}[^/]*\$" <<<"$file" | head -1)
		fi
		if [ -z "$file" ]; then
			local resp asset name
			if [ "$is_gitlab" = true ]; then
				resp=$(req "$rv_rel" -) || return 1
				if [ "$ver" = "latest" ]; then resp=$(jq -e '.[0]' <<<"$resp") || return 1; fi
				tag_name=$(jq -r '.tag_name' <<<"$resp") || return 1
				matches=$(jq -e '.assets.links | map(select(.name | (endswith("asc") or endswith("json") or endswith("txt")) | not))' <<<"$resp") || return 1
			else
				resp=$(gh_req "$rv_rel" -) || return 1
				tag_name=$(jq -r '.tag_name' <<<"$resp") || return 1
				matches=$(jq -e '.assets | map(select(.name | (endswith("asc") or endswith("json") or endswith("txt")) | not))' <<<"$resp") || return 1
			fi
			if [ "$(jq 'length' <<<"$matches")" -gt 1 ]; then
				local matches_new
				matches_new=$(jq -e -r 'map(select(.name | contains("-dev") | not))' <<<"$matches")
				if [ "$(jq 'length' <<<"$matches_new")" -eq 1 ]; then
					matches=$matches_new
				fi
			fi
			if [ "$(jq 'length' <<<"$matches")" -eq 0 ]; then
				epr "No asset was found"
				return 1
			elif [ "$(jq 'length' <<<"$matches")" -ne 1 ]; then
				wpr "More than 1 asset was found for this release. Falling back to the first one found..."
			fi
			asset=$(jq -r ".[0]" <<<"$matches")
			url=$(jq -r .url <<<"$asset")
			name=$(jq -r .name <<<"$asset")
			file="${dir}/${name}"
			if [ "$is_gitlab" = true ]; then
				if [ ! -f "$file" ]; then
					pr "Getting '$file' from '$url'" >&2
					req "$url" "$file" >&2 || return 1
				fi
			else
				gh_dl "$file" "$url" >&2 || return 1
			fi
			if [ "$tag" = CLI ]; then
				# The CLI line goes into its own file, so build.md lists it after all Patches lines.
				echo "$tag: $(cut -d/ -f1 <<<"$bare_src")/${name}  " >>"${TEMP_DIR}/cli-changelog.md"
			else
				echo "$tag: $(cut -d/ -f1 <<<"$bare_src")/${name}  " >>"$cl_file"
			fi
		else
			grab_cl=false
			name=$(basename "$file")
			tag_name=$(cut -d'-' -f3- <<<"$name")
			tag_name=v${tag_name%.*}
		fi

		if [ "$tag" = "Patches" ]; then
			if [ "$grab_cl" = true ]; then
				if [ "$is_gitlab" = true ]; then
					echo -e "[Changelog](https://gitlab.com/${bare_src}/-/releases/${tag_name})\n" >>"$cl_file"
				else
					echo -e "[Changelog](https://github.com/${bare_src}/releases/tag/${tag_name})\n" >>"$cl_file"
				fi
			fi
			if [ "$REMOVE_RV_INTEGRATIONS_CHECKS" = true ]; then
				local extensions_ext
				extensions_ext=$(unzip -l "${file}" "extensions/shared.*" | grep -o "shared\..*") extensions_ext="${extensions_ext#*.}"
				if ! (
					mkdir -p "${file}-zip" || return 1
					unzip -qo "${file}" -d "${file}-zip" || return 1
					java -cp "${BIN_DIR}/paccer.jar:${BIN_DIR}/dexlib2.jar" com.jhc.Main "${file}-zip/extensions/shared.${extensions_ext}" "${file}-zip/extensions/shared-patched.${extensions_ext}" || return 1
					mv -f "${file}-zip/extensions/shared-patched.${extensions_ext}" "${file}-zip/extensions/shared.${extensions_ext}" || return 1
					rm "${file}" || return 1
					cd "${file}-zip" || abort
					zip -0rq "${CWD}/${file}" . || return 1
				) >&2; then
					echo >&2 "Patching revanced-integrations failed"
				fi
				rm -r "${file}-zip" || :
			fi
		fi
		echo -n "$file "
	done
	echo
}

set_prebuilts() {
	APKSIGNER="${BIN_DIR}/apksigner.jar"
	local arch
	arch=$(uname -m)
	if [ "$arch" = aarch64 ]; then arch=arm64; elif [ "${arch:0:5}" = "armv7" ]; then arch=arm; fi
	HTMLQ="${BIN_DIR}/htmlq/htmlq-${arch}"
	AAPT2="${BIN_DIR}/aapt2/aapt2-${arch}"
	TOML="${BIN_DIR}/toml/tq-${arch}"
}

# Find the current patch-bundle asset name for a source and a version, for example
# "patches-1.19.0.mpp". It picks the same asset that get_prebuilts downloads, so the name can be
# compared with the name that a build recorded. It sets LATEST_NAME, which stays empty on failure,
# and it returns 1 when an API error prevents the lookup. The result is cached for each "src/ver"
# in latest_cache[], which belongs to the caller. Call this function directly. In a $() subshell
# the cache write is lost.
_latest_patches_name() {
	local PATCHES_SRC=$1 PATCHES_VER=$2 key="$1/$2"
	if [[ -v latest_cache["$key"] ]]; then
		LATEST_NAME="${latest_cache["$key"]}"
		[ -n "$LATEST_NAME" ]
		return
	fi
	latest_cache["$key"]="" LATEST_NAME="" # the default for a failure. Success overwrites it.
	local is_gitlab_cu=false bare_patches_src="$PATCHES_SRC"
	if [[ "$PATCHES_SRC" == gitlab:* ]]; then is_gitlab_cu=true; bare_patches_src="${PATCHES_SRC#gitlab:}"; fi
	local rv_rel resp
	if [ "$is_gitlab_cu" = true ]; then
		rv_rel="https://gitlab.com/api/v4/projects/${bare_patches_src//\//%2F}/releases"
	else
		rv_rel="https://api.github.com/repos/${bare_patches_src}/releases"
	fi
	if [ "$PATCHES_VER" = "dev" ] || [ "$PATCHES_VER" = "latest" ]; then
		if [ "$is_gitlab_cu" = true ]; then
			resp=$(req "$rv_rel" - | jq -e '.[0]') || return 1
		elif [ "$PATCHES_VER" = "dev" ]; then
			resp=$(gh_req "$rv_rel" - | jq -e '.[0]') || return 1
		else
			resp=$(gh_req "$rv_rel/latest" -) || return 1
		fi
	else
		if [ "$is_gitlab_cu" = true ]; then
			resp=$(req "$rv_rel/${PATCHES_VER}" -) || return 1
		else
			resp=$(gh_req "$rv_rel/tags/${PATCHES_VER}" -) || return 1
		fi
	fi
	# Select the same asset as get_prebuilts. Remove the .asc, .json and .txt checksum files. If
	# more than one asset remains, prefer the build without "-dev" when only one such build
	# remains. Then take the first asset.
	local matches
	if [ "$is_gitlab_cu" = true ]; then
		matches=$(jq -e '.assets.links | map(select(.name | (endswith("asc") or endswith("json") or endswith("txt")) | not))' <<<"$resp") || return 1
	else
		matches=$(jq -e '.assets | map(select(.name | (endswith("asc") or endswith("json") or endswith("txt")) | not))' <<<"$resp") || return 1
	fi
	if [ "$(jq 'length' <<<"$matches")" -gt 1 ]; then
		local matches_new
		if matches_new=$(jq -e 'map(select(.name | contains("-dev") | not))' <<<"$matches") && [ "$(jq 'length' <<<"$matches_new")" -eq 1 ]; then
			matches=$matches_new
		fi
	fi
	local name
	name=$(jq -e -r '.[0].name' <<<"$matches") || return 1
	latest_cache["$key"]=$name LATEST_NAME=$name
}

# Return 0 if $table needs a rebuild for patches source $1@$2. This is true when the current
# asset differs from the asset recorded for this app in PATCHES_STATE_FILE, and also when nothing
# is recorded yet. Return 1 in all other cases. A source that the API cannot resolve counts as
# "no change", so a temporary API error never starts a full build.
_patches_src_changed() {
	local PATCHES_SRC=$1 PATCHES_VER=$2 table=$3 recorded
	_latest_patches_name "$PATCHES_SRC" "$PATCHES_VER" || return 1 # sets LATEST_NAME
	recorded=$(jq -r --arg t "$table" --arg s "$PATCHES_SRC" '.[$t][$s] // ""' "$PATCHES_STATE_FILE" 2>/dev/null) || recorded=""
	[ "$LATEST_NAME" != "$recorded" ]
}

config_update() {
	[ -f "$PATCHES_STATE_FILE" ] || echo '{}' >"$PATCHES_STATE_FILE"
	declare -A latest_cache
	local LATEST_NAME="" upped=()
	for table_name in $(toml_get_table_names); do
		if [ -z "$table_name" ]; then continue; fi
		t=$(toml_get_table "$table_name")
		enabled=$(toml_get "$t" enabled) || enabled=true
		if [ "$enabled" = "false" ]; then continue; fi
		PATCHES_SRC=$(toml_get "$t" patches-source) || PATCHES_SRC=$DEF_PATCHES_SRC
		PATCHES_VER=$(toml_get "$t" patches-version) || PATCHES_VER=$DEF_PATCHES_VER
		local up=false
		if _patches_src_changed "$PATCHES_SRC" "$PATCHES_VER" "$table_name"; then up=true; fi
		if EXTRA_SRC=$(toml_get "$t" extra-patches-source); then
			EXTRA_VER=$(toml_get "$t" extra-patches-version) || EXTRA_VER="latest"
			if _patches_src_changed "$EXTRA_SRC" "$EXTRA_VER" "$table_name"; then up=true; fi
		fi
		if [ "$up" = true ]; then upped+=("$table_name"); fi
	done
	if [ ${#upped[@]} -ne 0 ]; then
		local query=""
		for table in "${upped[@]}"; do
			if [ -n "$query" ]; then query+=" or "; fi
			query+=".key == \"$table\""
		done
		jq "to_entries | map(select(${query} or (.value | type != \"object\"))) | from_entries" <<<"$__TOML__"
	fi
}

_req() {
	local ip="$1" op="$2"
	shift 2
	local dlp="$op"
	if [ "$op" != - ]; then
		if [ -f "$op" ]; then return; fi
		dlp="$(dirname "$op")/tmp.$(basename "$op")"
		if [ -f "$dlp" ]; then
			while [ -f "$dlp" ]; do sleep 1; done
			return
		fi
	fi
	if ! curl -L -c "$TEMP_DIR/cookie.txt" -b "$TEMP_DIR/cookie.txt" --connect-timeout 10 --retry 1 --fail -s -S "$@" "$ip" -o "$dlp"; then
		epr "Request failed: $ip"
		if [ "$dlp" != - ]; then rm -f "$dlp"; fi
		return 1
	fi
	if [ "$dlp" != - ]; then
		mv -f "$dlp" "$op"
	fi
}
req() { _req "$1" "$2" -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:108.0) Gecko/20100101 Firefox/108.0"; }
gh_req() { _req "$1" "$2" -H "$GH_HEADER"; }
gh_dl() {
	if [ ! -f "$1" ]; then
		pr "Getting '$1' from '$2'"
		_req "$2" "$1" -H "$GH_HEADER" -H "Accept: application/octet-stream"
	fi
}

log() { echo -e "$1  " >>"build.md"; }
# Append one "<app>\t<patches-source>\t<asset-name>" line for each bundle that built. After all
# builds finish, build.sh writes these lines into BUILT_PATCHES_FILE, and build.yml merges that
# file into PATCHES_STATE_FILE. This function runs on success only. Thus a failed build stays
# unrecorded, and the next run tries it again.
log_built_patches() { printf '%s\t%s\t%s\n' "$1" "$2" "$(basename "$3")" >>"${TEMP_DIR}/built-patches.tsv"; }
# The path of the changelog part for one patches source. The part holds the "Patches:" and
# "[Changelog]" lines. The key is the full source string ($1), for example "crimera/piko" or
# "gitlab:inotia00/x-shim", so that it matches column 2 of built-patches.tsv. get_prebuilts writes
# the part at download time. build.sh emits only the parts whose source shipped, so the bundle of
# a failed build never appears in the release notes. '/' and ':' become '_' to make a flat
# filename.
cl_changelog_file() { local k=${1//\//_}; k=${k//:/_}; echo "${TEMP_DIR}/changelogs/${k}.md"; }
# Record an enabled app that did not ship, with its table name and a short reason. build.sh and
# build.yml report it. Background build_rv jobs append to this file. Each call writes one short
# line, which keeps the append atomic.
record_failure() { printf '%s\t%s\n' "$1" "${2:-build failed}" >>"$FAILED_BUILDS_FILE"; }
# Record a build warning, with its table name and a message, for build.sh and build.yml to
# report. It appends one line, like record_failure. It is used for 'auto' version step-downs.
record_warning() { printf '%s\t%s\n' "$1" "${2:-}" >>"$BUILD_WARNINGS_FILE"; }
get_highest_ver() {
	local vers m
	vers=$(tee)
	m=$(head -1 <<<"$vers")
	if ! semver_validate "$m"; then echo "$m"; else sort -s -t- -k1,1Vr <<<"$vers" | head -1; fi
}
semver_validate() {
	local a="${1%-*}"
	local a="${a#v}"
	local ac="${a//[.0-9]/}"
	[ ${#ac} = 0 ]
}
# Sort a version list, one version per line, highest first. It understands semver. It works like
# get_highest_ver, but it keeps the whole list. get_highest_ver is the same as this | head -1.
_sort_vers_desc() {
	local vers m
	vers=$(tee)
	m=$(head -1 <<<"$vers")
	if ! semver_validate "$m"; then echo "$vers"; else sort -s -t- -k1,1Vr <<<"$vers"; fi
}
# Echo the versions that one patches bundle supports for $pkg_name, highest first, one per line.
# It reads $cli_jar and $pkg_name from the caller. It echoes nothing when the bundle sets no
# version limit. $2 is 'lenient'. When it is true, a bundle that reports no compatible version
# counts as "no limit" instead of a fatal error. Extra-patches bundles use this, because such a
# bundle can correctly contribute no versioned patch. One example is the x-shim shim applied with
# Piko. morphe-desktop 1.11.0 and later omit the versions section for such a bundle. Older CLIs
# printed "Any". Both cases mean the same thing here.
_supported_vers_for_jar() {
	local pj=$1 lenient=${2:-false} is_experimental=${3:-false} op pcount
	op=$(patches_list_versions "$cli_jar" "$pj" "$pkg_name" "$is_experimental") || return 1
	# morphe-cli 1.14.0 and later append ' [versionCodes: ARM64_V8A=..., ...]' to each version line,
	# for bundles whose targets declare version codes (De-Vanced, Piko, rushiranpise). Remove it.
	# If it stays, the resolved 'version' keeps the suffix and no download source can match it.
	op=$(sed -n '/Most common compatible versions:/,$p' <<<"$op" |
		sed '1d;s/ \[versionCodes:[^]]*\]//' | awk '{$1=$1}1')
	if [ "$op" = "Any" ]; then return; fi
	if [ -z "$op" ]; then
		# list-versions gave no version tier. Either the bundle has no patch for this package, or
		# its patches set no version limit. A package with no version limit prints nothing here,
		# not "Any". The list-patches output of the caller tells the two apart, as in the pcount
		# branch below. If the package has patches, there is no version limit, and the empty
		# return makes 'auto' fall back to the latest version. If not, the package truly has none.
		{ [ "$lenient" = true ] || grep -Fq "$pkg_name" <<<"${list_patches:-}"; } && return
		abort "No patches found for '$pkg_name' in patches '$pj'"
	fi
	pcount=$(head -1 <<<"$op") pcount=${pcount#*(} pcount=${pcount% *}
	if [ -z "$pcount" ]; then
		# The package has patches, but none of them set a version limit, because the patch count
		# cannot be parsed. Treat this as no limit instead of an abort. $list_patches is the
		# list-patches output of the caller, get_patch_last_supported_ver.
		{ [ "$lenient" = true ] || grep -Fq "$pkg_name" <<<"${list_patches:-}"; } && return
		abort "No patches found for '$pkg_name' in patches '$pj'"
	fi
	# Every version in the top tier, which all $pcount patches support, highest first.
	grep -F "($pcount patch" <<<"$op" | sed 's/ (.* patch.*//' | _sort_vers_desc || return 1
}
# Echo the versions that the primary bundle and every extra-patches bundle support together,
# highest first, one per line. The output is empty when no bundle sets a version limit. The exit
# code is not zero when list-patches fails hard. In 'auto' mode the caller takes line 1. If no
# source can download that version, the caller walks down the rest of the list. Thus a version
# that a bundle declares but nobody hosts falls back to the highest version that is available.
# One past example: Paresh listed Telegram-web 12.9.1, for which no web APK existed. The name of
# this function is unchanged, to keep upstream merges simple, but it now returns the whole ranked
# list, not the last version only.
get_patch_last_supported_ver() {
	local list_patches=$1 pkg_name=$2 inc_sel=$3 is_experimental=$4
	local op
	if [ "$inc_sel" ]; then
		if ! op=$(awk '{$1=$1}1' <<<"$list_patches"); then
			epr "list-patches: '$op'"
			return 1
		fi
		local ver vers="" n=0 NL=$'\n'
		while IFS= read -r line; do
			line="${line:1:${#line}-2}"
			ver=$(sed -n "/^Name: $line\$/,/^\$/p" <<<"$op" | sed -n "/^Compatible versions:\$/,/^\$/p" | tail -n +2)
			if [ -n "$ver" ]; then vers+=${ver}${NL}; n=$((n + 1)); fi
		done <<<"$(list_args "$inc_sel")"
		vers=$(awk '{$1=$1}1' <<<"$vers" | grep -v '^$' || :)
		if [ "$vers" ] && [ "$n" -gt 0 ]; then
			# A version that all n included patches support appears n times.
			local common
			common=$(sort <<<"$vers" | uniq -c | awk -v n="$n" '$1 == n {print $2}')
			if [ "$common" ]; then _sort_vers_desc <<<"$common"; return; fi
		fi
		# If not, use the primary bundle and extra bundle resolution below.
	fi
	# The versions that the primary bundle and every extra-patches bundle support, highest first.
	# An extra bundle with no version limit gives an empty list, for example the x-shim shim, and
	# it does not make the set smaller. Patches are compatible downward, so a step down this list
	# is safe for every bundle applied together. is_experimental is passed on, so 'experimental'
	# mode also resolves the version against the experimental patches (CLI -x).
	local vers ej ejv
	vers=$(_supported_vers_for_jar "$patches_jar" false "$is_experimental") || return 1
	for ej in ${args[ptjar_extra]:-}; do
		ejv=$(_supported_vers_for_jar "$ej" true "$is_experimental") || return 1
		[ -z "$ejv" ] && continue
		vers=$(comm -12 <(sort <<<"$vers") <(sort <<<"$ejv"))
	done
	vers=$(grep -v '^$' <<<"$vers" || :)
	if [ -z "$vers" ]; then return; fi
	_sort_vers_desc <<<"$vers"
}

patches_list_versions() {
	local cli_jar=$1 patches_jar=$2 pkg_name=$3 is_experimental=$4
	local cmd_base="java -jar '$cli_jar' list-versions"

	# TODO: remove this later
	local cli_name
	cli_name=$(basename "$cli_jar")
	if [ "${cli_name::8}" = "revanced" ]; then
		cmd_base+=" -b"
	elif [ "$is_experimental" = "true" ]; then
		cmd_base+=" -x"
	fi

	local cmd="${cmd_base} --patches='$patches_jar' -f '$pkg_name'"
	if op=$(eval "$cmd" 2>&1); then
		echo "$op"
		return
	fi

	cmd="${cmd_base} '$patches_jar' -f '$pkg_name'"
	if op=$(eval "$cmd" 2>&1); then
		echo "$op"
		return
	fi

	epr "Could not list versions ($pkg_name) $cli_jar: '$op'"
	return 1
}
patches_list() {
	local cli_jar=$1 patches_jar=$2 pkg_name=$3 is_experimental=$4
	local op
	if ! op=$(java -jar "$cli_jar" list-patches -p "$patches_jar" --filter-package-name "$pkg_name" --versions --packages -b 2>&1); then
		local cmd="java -jar '$cli_jar' list-patches --patches '$patches_jar' -f '$pkg_name' --with-versions --with-packages"
		if [ "$is_experimental" = "true" ]; then cmd+=" -x"; fi
		if ! op=$(eval "$cmd" 2>&1); then
			epr "Could not get patches list ($pkg_name) $cli_jar: '$op'"
			return 1
		fi

	fi
	echo "$op"
}

isoneof() {
	local i=$1 v
	shift
	for v; do [ "$v" = "$i" ] && return 0; done
	return 1
}

merge_splits() {
	local bundle=$1 output=$2
	pr "Merging splits"
	gh_dl "$TEMP_DIR/apkeditor.jar" "https://github.com/REAndroid/APKEditor/releases/download/V1.4.7/APKEditor-1.4.7.jar" >/dev/null || return 1
	if ! OP=$(java -jar "$TEMP_DIR/apkeditor.jar" merge -i "$bundle" -o "${output}-unsigned" -clean-meta -f 2>&1); then
		epr "APKEditor error: $OP"
		return 1
	fi
	# Sign the merged stock apk.
	if ! OP=$(java -jar "$APKSIGNER" sign --ks ks-p12.keystore --ks-pass pass:123456789 --key-pass pass:123456789 --ks-key-alias andrewliang \
		--out "${output}" "${output}-unsigned"); then
		epr "apksigner error: $OP"
		return 1
	fi
	rm "${output}.idsig" "${output}-unsigned" 2>/dev/null || :
	return 0
}

# -------------------- apkmirror --------------------
apkmirror_search() {
	local resp="$1" dpi="$2" arch="$3" apk_bundle="$4"
	local dlurl="" node app_table emptyCheck

	local apparch=('universal' 'noarch' 'arm64-v8a + armeabi-v7a')
	if [ "$arch" != "all" ]; then
		apparch+=("$arch")
	fi

	local appdpi=("nodpi" "anydpi")
	if [ "$dpi" ]; then
		appdpi+=($dpi)
	fi

	for ((n = 1; n < 40; n++)); do
		node=$($HTMLQ "div.table-row.headerFont:nth-last-child($n)" -r "span:nth-child(n+3)" <<<"$resp")
		if [ -z "$node" ]; then break; fi
		emptyCheck=$($HTMLQ -t -w "div.table-cell:nth-child(1) > a:nth-child(1)" <<<"$node" | xargs)
		if [ -z "$emptyCheck" ]; then break; fi
		app_table=$($HTMLQ --text --ignore-whitespace <<<"$node")
		if [ "$(sed -n 3p <<<"$app_table")" != "$apk_bundle" ]; then continue; fi
		dlurl=$($HTMLQ --base https://www.apkmirror.com --attribute href "div:nth-child(1) > a:nth-child(1)" <<<"$node")
		if isoneof "$(sed -n 6p <<<"$app_table")" "${appdpi[@]}" &&
			isoneof "$(sed -n 4p <<<"$app_table")" "${apparch[@]}"; then
			echo "$dlurl"
			return 0
		fi
	done
	if [ "$n" -eq 2 ] && [ "$dlurl" ]; then
		# Only one apk exists. Return it.
		echo "$dlurl"
		return 0
	fi
	return 1
}
dl_apkmirror() {
	local url=$1 version=${2// /-} output=$3 arch=$4 dpi=$5 is_bundle=false

	if [ -f "${output}.apkm" ]; then
		merge_splits "${output}.apkm" "${output}"
		return 0
	fi

	if [ "$arch" = "arm-v7a" ]; then arch="armeabi-v7a"; fi
	local resp node app_table apkmname dlurl=""
	apkmname=$($HTMLQ "h1.marginZero" --text <<<"$__APKMIRROR_RESP__")
	apkmname="${apkmname,,}" apkmname="${apkmname// /-}" apkmname="${apkmname//[^a-z0-9-]/}"
	url="${url}/${apkmname}-${version//./-}-release/"
	resp=$(req "$url" -) || return 1
	node=$($HTMLQ "div.table-row.headerFont:nth-last-child(1)" -r "span:nth-child(n+3)" <<<"$resp")
	if [ "$node" ]; then
		for type in APK BUNDLE; do
			if dlurl=$(apkmirror_search "$resp" "$dpi" "$arch" "$type"); then
				if [ "$type" = "BUNDLE" ]; then
					is_bundle=true
				else is_bundle=false; fi
				break 2
			fi
		done
		if [ -z "$dlurl" ]; then return 1; fi
		resp=$(req "$dlurl" -)
	fi
	url=$(echo "$resp" | $HTMLQ --base https://www.apkmirror.com --attribute href "a.btn") || return 1
	url=$(req "$url" - | $HTMLQ --base https://www.apkmirror.com --attribute href "span > a[rel = nofollow]") || return 1

	if [ "$is_bundle" = true ]; then
		req "$url" "${output}.apkm" || return 1
		merge_splits "${output}.apkm" "${output}"
	else
		req "$url" "${output}" || return 1
	fi
}
get_apkmirror_vers() {
	local vers apkm_resp
	apkm_resp=$(req "https://www.apkmirror.com/uploads/?appcategory=${__APKMIRROR_CAT__}" -)
	vers=$(sed -n 's;.*Version:</span><span class="infoSlide-value">\(.*\) </span>.*;\1;p' <<<"$apkm_resp" | awk '{$1=$1}1')

	vers=$(grep -iv "\(beta\|alpha\)" <<<"$vers")
	local v r_vers=()
	local IFS=$'\n'
	for v in $vers; do
		grep -iq "${v} \(beta\|alpha\)" <<<"$apkm_resp" || r_vers+=("$v")
	done
	echo "${r_vers[*]}"
}
get_apkmirror_pkg_name() { sed -n 's;.*id=\(.*\)" class="accent_color.*;\1;p' <<<"$__APKMIRROR_RESP__"; }
get_apkmirror_resp() {
	__APKMIRROR_RESP__=$(req "${1}" -) || return 1
	__APKMIRROR_CAT__="${1##*/}"
}

# -------------------- uptodown --------------------
get_uptodown_resp() {
	__UPTODOWN_RESP__=$(req "${1}/versions" -) || return 1
	__UPTODOWN_RESP_PKG__=$(req "${1}/download" -) || return 1
}
get_uptodown_vers() { $HTMLQ --text ".version" <<<"$__UPTODOWN_RESP__"; }
dl_uptodown() {
	local uptodown_dlurl=$1 version=$2 output=$3 arch=$4 _dpi=$5
	if [ "$arch" = "arm-v7a" ]; then arch="armeabi-v7a"; fi

	local apparch=('arm64-v8a, armeabi-v7a, x86_64' 'arm64-v8a, armeabi-v7a, x86, x86_64' 'arm64-v8a, armeabi-v7a')
	if [ "$arch" != "all" ]; then
		apparch+=("$arch")
	fi

	local op resp data_code
	data_code=$($HTMLQ "#detail-app-name" --attribute data-code <<<"$__UPTODOWN_RESP__")
	local versionURL=""
	local is_bundle=false
	for i in {1..20}; do
		resp=$(req "${uptodown_dlurl}/apps/${data_code}/versions/${i}" -)
		if ! op=$(jq -e -r ".data | map(select(.version == \"${version}\")) | .[0]" <<<"$resp"); then
			continue
		fi
		if [ "$(jq -e -r ".kindFile" <<<"$op")" = "xapk" ]; then is_bundle=true; fi
		if versionURL=$(jq -e -r '.versionURL' <<<"$op"); then break; else return 1; fi
	done
	if [ -z "$versionURL" ]; then return 1; fi
	versionURL=$(jq -e -r '.url + "/" + .extraURL + "/" + (.versionID | tostring)' <<<"$versionURL")
	resp=$(req "$versionURL" -) || return 1

	local data_version files node_arch="" data_file_id node_class
	data_version=$($HTMLQ '.button.variants' --attribute data-version <<<"$resp") || return 1
	if [ "$data_version" ]; then
		files=$(req "${uptodown_dlurl%/*}/app/${data_code}/version/${data_version}/files" - | jq -e -r .content) || return 1
		for ((n = 1; n < 12; n += 1)); do
			node_class=$($HTMLQ -w -t ".content > :nth-child($n)" --attribute class <<<"$files") || return 1
			if [ "$node_class" != "variant" ]; then
				node_arch=$($HTMLQ -w -t ".content > :nth-child($n)" <<<"$files" | xargs) || return 1
				continue
			fi
			if [ -z "$node_arch" ]; then return 1; fi
			if ! isoneof "$node_arch" "${apparch[@]}"; then continue; fi

			file_type=$($HTMLQ -w -t ".content > :nth-child($n) > .v-file > span" <<<"$files") || return 1
			if [ "$file_type" = "xapk" ]; then is_bundle=true; else is_bundle=false; fi
			data_file_id=$($HTMLQ ".content > :nth-child($n) > .v-report" --attribute data-file-id <<<"$files") || return 1
			resp=$(req "${uptodown_dlurl}/download/${data_file_id}-x" -)
			break
		done
		if [ $n -eq 12 ]; then return 1; fi
	fi
	local data_url
	data_url=$($HTMLQ "#detail-download-button" --attribute data-url <<<"$resp") || return 1
	if [ $is_bundle = true ]; then
		req "https://dw.uptodown.com/dwn/${data_url}" "$output.apkm" || return 1
		merge_splits "${output}.apkm" "${output}"
	else
		req "https://dw.uptodown.com/dwn/${data_url}" "$output"
	fi
}
get_uptodown_pkg_name() { $HTMLQ --text "tr.full:nth-child(1) > td:nth-child(3)" <<<"$__UPTODOWN_RESP_PKG__"; }

# -------------------- archive --------------------
dl_archive() {
	local url=$1 version=$2 output=$3 arch=$4
	local path version=${version// /}

	if [ -f "${output}.apkm" ]; then
		merge_splits "${output}.apkm" "$output"
		return 0
	fi

	if ! path=$(grep -m1 "${version_f#v}-${arch// /}" <<<"$__ARCHIVE_RESP__"); then
		path=$(grep -m1 "${version_f#v}-all" <<<"$__ARCHIVE_RESP__") || return 1
	fi

	if [ "${path##*.}" = "apkm" ]; then
		req "${url}/${path}" "${output}.apkm" || return 1
		merge_splits "${output}.apkm" "$output"
	else
		req "${url}/${path}" "${output}" || return 1
	fi
}
get_archive_resp() {
	local r
	r=$(req "$1" -)
	if [ -z "$r" ]; then return 1; else __ARCHIVE_RESP__=$(sed -n 's;^<a href="\(.*\)"[^"]*;\1;p' <<<"$r"); fi
	__ARCHIVE_PKG_NAME__=$(awk -F/ '{print $NF}' <<<"$1")
}
get_archive_vers() { sed 's/^[^-]*-//;s/-\(all\|arm64-v8a\|arm-v7a\)\.apkm\{0,1\}//g' <<<"$__ARCHIVE_RESP__"; }
get_archive_pkg_name() { echo "$__ARCHIVE_PKG_NAME__"; }

# -------------------- direct --------------------
dl_direct() {
	local url=$1 version=${2// /-} output=$3 arch=$4 _dpi=$5
	if ! grep -q "${version_f#v}-${arch// /}" <<<"$url"; then
		epr "Given direct-dlurl for $output is not compatible. Set proper 'arch' and 'version' options."
		return 1
	fi
	if [ "${url##*.}" = "apkm" ]; then
		req "$url" "${output}.apkm" || return 1
		merge_splits "${output}.apkm" "$output"
	else
		req "$url" "${output}" || return 1
	fi
}
get_direct_vers() { cut -d- -f2 <<<"$__DIRECT_APKNAME__"; }
get_direct_pkg_name() { cut -d- -f1 <<<"$__DIRECT_APKNAME__"; }
get_direct_resp() { __DIRECT_APKNAME__=$(awk -F/ '{print $NF}' <<<"$1"); }
# --------------------------------------------------

patch_apk() {
	local stock_input=$1 patched_apk=$2 patcher_args=$3 cli_jar=$4 patches_jar=$5 extra_patches=${6:-}
	local tmp_files
	tmp_files="$(pwd)/$(mktemp -d -p "$TEMP_DIR")"

	local cmd="java -jar '$cli_jar' patch '$stock_input' -o '$patched_apk' -p '$patches_jar' --keystore=ks.keystore \
--keystore-entry-password=123456789 --keystore-password=123456789 --signer=andrewliang --keystore-entry-alias=andrewliang -t '$tmp_files' $patcher_args"
	# More patch bundles, applied together with the primary one (for example x-shim with Piko).
	local ep
	for ep in $extra_patches; do cmd+=" -p '$ep'"; done

	# TODO: remove this later
	local cli_name
	cli_name=$(basename "$cli_jar")
	if [ "${cli_name::8}" = revanced ]; then cmd+=" -b"; fi

	if [ "$OS" = Android ]; then cmd+=" --custom-aapt2-binary='${AAPT2}'"; fi
	pr "$cmd"
	if eval "$cmd"; then [ -f "$patched_apk" ]; else
		rm "$patched_apk" 2>/dev/null || :
		return 1
	fi
}

check_sig() {
	local file=$1 pkg_name=$2
	local sig
	if grep -q "$pkg_name" sig.txt; then
		sig=$(java -jar "$APKSIGNER" verify --print-certs "$file" | grep ^Signer | grep SHA-256 | tail -1 | awk '{print $NF}')
		echo "$pkg_name signature: ${sig}"
		grep -qFx "$sig $pkg_name" sig.txt
	fi
}

build_rv() {
	eval "declare -A args=${1#*=}"
	local version="" pkg_name=""
	local mode_arg=${args[build_mode]} version_mode=${args[version]}
	local app_name=${args[app_name]}
	local app_name_l=${app_name,,}
	app_name_l=${app_name_l// /-}
	local table=${args[table]}
	local dl_from=${args[dl_from]}
	local arch=${args[arch]}
	local arch_f="${arch// /}"
	local built_ok=false # true after any (mode, arch) build of this app succeeds

	local p_patcher_args=()
	if [ "${args[excluded_patches]}" ]; then p_patcher_args+=("$(join_args "${args[excluded_patches]}" -d)"); fi
	if [ "${args[included_patches]}" ]; then p_patcher_args+=("$(join_args "${args[included_patches]}" -e)"); fi
	[ "${args[exclusive_patches]}" = true ] && p_patcher_args+=("--exclusive")

	local tried_dl=()
	if [ "${args[pkg_name]}" ]; then
		pkg_name="${args[pkg_name]}"
	else
		for dl_p in "${DL_SRCS[@]}"; do
			if [ -z "${args[${dl_p}_dlurl]}" ]; then continue; fi
			if ! get_${dl_p}_resp "${args[${dl_p}_dlurl]}" || ! pkg_name=$(get_"${dl_p}"_pkg_name); then
				args[${dl_p}_dlurl]=""
				epr "ERROR: Could not find ${table} in ${dl_p}"
				continue
			fi
			tried_dl+=("$dl_p")
			dl_from=$dl_p
			break
		done
	fi

	if [ -z "$pkg_name" ]; then
		epr "empty pkg name, not building ${table}."
		record_failure "$table" "could not resolve package name"
		return 0
	fi
	pr "Package name of '${table}' is '$pkg_name'"
	local list_patches

	local is_experimental="false"
	if [ "$version_mode" = "experimental" ]; then is_experimental="true"; fi
	list_patches=$(patches_list "$cli_jar" "$patches_jar" "$pkg_name" "$is_experimental") || return 1
	local get_latest_ver=false
	local -a version_candidates=()
	if isoneof "$version_mode" auto experimental; then
		local supported_vers
		if ! supported_vers=$(get_patch_last_supported_ver "$list_patches" "$pkg_name" \
			"${args[included_patches]}" "$is_experimental"); then
			epr "get_patch_last_supported_ver failed '$list_patches'"
			return
		fi
		if [ -z "$supported_vers" ]; then
			get_latest_ver=true
		else
			# Line 1 is the pick. The other lines are fallbacks. The code below tries them in
			# order if no source can download the pick. This occurs when a bundle declares a
			# version that nobody hosts.
			mapfile -t version_candidates <<<"$supported_vers"
			version=${version_candidates[0]}
		fi
	elif [ "$version_mode" = latest ]; then
		get_latest_ver=true
		p_patcher_args+=("-f")
	else
		version=$version_mode
		p_patcher_args+=("-f")
	fi
	if [ $get_latest_ver = "true" ]; then
		pkgvers=$(get_"${dl_from}"_vers)
		version=$(get_highest_ver <<<"$pkgvers") || version=$(head -1 <<<"$pkgvers")
	fi
	if [ -z "$version" ]; then
		epr "empty version, not building ${table}."
		record_failure "$table" "could not resolve version"
		return 0
	fi
	# Modes other than 'auto', and the get_latest_ver path, resolve one version only, with no step-down.
	if [ ${#version_candidates[@]} -eq 0 ]; then version_candidates=("$version"); fi

	if [ "$mode_arg" = module ]; then
		build_mode_arr=(module)
	elif [ "$mode_arg" = apk ]; then
		build_mode_arr=(apk)
	elif [ "$mode_arg" = both ]; then
		build_mode_arr=(apk module)
	fi

	# Try each candidate version, highest first. The inner loop already tries every configured
	# source, so the code steps down to the next version only after every source fails.
	local version_f stock_apk cand dled=false
	for cand in "${version_candidates[@]}"; do
		version=$cand
		pr "Choosing version '${version}' for ${table}"
		version_f=${version// /}
		version_f=${version_f#v}
		stock_apk="${TEMP_DIR}/${pkg_name}-${version_f}-${arch_f}.apk"
		if [ -f "$stock_apk" ]; then dled=true; break; fi
		for dl_p in "${DL_SRCS[@]}"; do
			if [ -z "${args[${dl_p}_dlurl]}" ]; then continue; fi
			pr "Downloading '${table}' from '${dl_p}'"
			if ! isoneof $dl_p "${tried_dl[@]}"; then
				if ! get_${dl_p}_resp "${args[${dl_p}_dlurl]}"; then
					epr "ERROR: Could not get '${table}' from '${dl_p}'"
					continue
				fi
				tried_dl+=("$dl_p")
			fi
			if ! dl_${dl_p} "${args[${dl_p}_dlurl]}" "$version" "$stock_apk" "$arch" "${args[dpi]}" "$get_latest_ver"; then
				epr "ERROR: Could not download '${table}' from '${dl_p}' with version '${version}', arch '${arch}', dpi '${args[dpi]}'"
				continue
			fi
			dled=true
			break
		done
		if [ "$dled" = true ]; then break; fi
		if [ ${#version_candidates[@]} -gt 1 ]; then
			wpr "'${table}' version '${version}' not downloadable from any source; trying next supported version"
		fi
	done
	if [ "$dled" != true ]; then
		epr "Stock apk not found for ${table} (tried: ${version_candidates[*]})"
		record_failure "$table" "stock apk download failed (${version_candidates[*]})"
		return 0
	fi
	# 'auto' stepped down. It shipped a supported version below the latest one, because the latest
	# one was not downloadable. The app still builds, so this is a warning, not a failure.
	if [ "$version" != "${version_candidates[0]}" ]; then
		wpr "'${table}' built '${version}', not latest supported '${version_candidates[0]}' (not downloadable)"
		record_warning "$table" "built ${version} — latest supported ${version_candidates[0]} not downloadable"
	fi

	local sig_op
	if [ -f "${stock_apk}.apkm" ]; then
		rm -rf "${stock_apk}-zip" || :
		unzip -j "${stock_apk}.apkm" -d "${stock_apk}-zip" >/dev/null
		for a in "${stock_apk}"-zip/*.apk; do
			if ! sig_op=$(check_sig "$a" "$pkg_name" 2>&1); then
				epr "Not building $table, apk signature mismatch '$a': $sig_op"
				record_failure "$table" "stock apk signature mismatch"
				return 0
			fi
		done
		rm -rf "${stock_apk}-zip" || :
	else
		if ! sig_op=$(check_sig "$stock_apk" "$pkg_name" 2>&1); then
			epr "Not building $table, apk signature mismatch '$stock_apk': $sig_op"
			record_failure "$table" "stock apk signature mismatch"
			return 0
		fi
	fi

	local microg_patch
	microg_patch=$(grep "^Name: " <<<"$list_patches" | grep -i "gmscore\|microg" || :) microg_patch=${microg_patch#*: }
	if [ -n "$microg_patch" ] && [[ ${p_patcher_args[*]} =~ $microg_patch ]]; then
		wpr "You cant include/exclude microg patch as that's done by rvmm builder automatically."
		p_patcher_args=("${p_patcher_args[@]//-[ei] ${microg_patch}/}")
	fi

	# Clone, in apk mode only. The package is renamed, so the apk installs beside the official app.
	# The module keeps the original package, because the rename patch is off in module mode.
	local clone_patch="" clone_pkg=""
	if [ "${args[clone]}" = true ]; then
		clone_patch=$(grep -m1 "^Name: Clone$" <<<"$list_patches" || grep -m1 "^Name: Change package name$" <<<"$list_patches") || :
		clone_patch=${clone_patch#*: }
		if [ -z "$clone_patch" ]; then
			epr "clone=true but no 'Clone'/'Change package name' patch found for $pkg_name; skipping clone"
		else
			local brand_pkg=${args[rv_brand],,} && brand_pkg=${brand_pkg//[^a-z0-9]/}
			clone_pkg="app.${brand_pkg}.${pkg_name#com.}"
		fi
	fi

	# Patch overrides for one mode make the apk and the module differ. Thus each mode must write to
	# its own filename, as microg and clone do, or one mode overwrites the file of the other.
	local per_mode_patches=false
	if [ -n "${args[apk_included_patches]:-}" ] || [ -n "${args[apk_excluded_patches]:-}" ] ||
		[ -n "${args[module_included_patches]:-}" ] || [ -n "${args[module_excluded_patches]:-}" ]; then
		per_mode_patches=true
	fi
	local patcher_args patched_apk build_mode
	local rv_brand_f=${args[rv_brand],,}
	rv_brand_f=${rv_brand_f//[^a-z0-9]/-} # slug for filenames: a space, '+' or other character becomes '-'
	if [ "${args[patcher_args]}" ]; then p_patcher_args+=("${args[patcher_args]}"); fi
	for build_mode in "${build_mode_arr[@]}"; do
		patcher_args=("${p_patcher_args[@]}")
		pr "Building '${table}' in '$build_mode' mode"
		if [ -n "$microg_patch" ] || [ -n "$clone_patch" ] || [ "$per_mode_patches" = true ]; then
			patched_apk="${TEMP_DIR}/${app_name_l}-${rv_brand_f}-${version_f}-${arch_f}-${build_mode}.apk"
		else
			patched_apk="${TEMP_DIR}/${app_name_l}-${rv_brand_f}-${version_f}-${arch_f}.apk"
		fi
		if [ -n "$microg_patch" ]; then
			if [ "$build_mode" = apk ]; then
				patcher_args+=("-e \"${microg_patch}\"")
			elif [ "$build_mode" = module ]; then
				patcher_args+=("-d \"${microg_patch}\"")
			fi
		fi
		if [ -n "$clone_patch" ] && [ "$build_mode" = apk ]; then
			patcher_args+=("-O packageName=${clone_pkg} -e \"${clone_patch}\"")
		fi
		# Fork-specific patch overrides for one mode. They exclude (-d) or include (-e) patches in
		# this build_mode only, on top of the shared patches already in patcher_args.
		if [ "$build_mode" = apk ]; then
			if [ -n "${args[apk_excluded_patches]:-}" ]; then patcher_args+=("$(join_args "${args[apk_excluded_patches]}" -d)"); fi
			if [ -n "${args[apk_included_patches]:-}" ]; then patcher_args+=("$(join_args "${args[apk_included_patches]}" -e)"); fi
		elif [ "$build_mode" = module ]; then
			if [ -n "${args[module_excluded_patches]:-}" ]; then patcher_args+=("$(join_args "${args[module_excluded_patches]}" -d)"); fi
			if [ -n "${args[module_included_patches]:-}" ]; then patcher_args+=("$(join_args "${args[module_included_patches]}" -e)"); fi
		fi

		local stock_apk_to_patch="${stock_apk}.stripped.apk"
		cp -f "$stock_apk" "$stock_apk_to_patch"
		if [ "$build_mode" = module ]; then
			zip -d "$stock_apk_to_patch" "lib/*" >/dev/null 2>&1 || :
		else
			if [ "$arch" = "arm64-v8a" ]; then
				zip -d "$stock_apk_to_patch" "lib/armeabi-v7a/*" "lib/x86_64/*" "lib/x86/*" >/dev/null 2>&1 || :
			elif [ "$arch" = "arm-v7a" ]; then
				zip -d "$stock_apk_to_patch" "lib/arm64-v8a/*" "lib/x86_64/*" "lib/x86/*" >/dev/null 2>&1 || :
			elif [ "$arch" = "x86" ]; then
				zip -d "$stock_apk_to_patch" "lib/arm64-v8a/*" "lib/x86_64/*" "lib/armeabi-v7a/*" >/dev/null 2>&1 || :
			elif [ "$arch" = "x86_64" ]; then
				zip -d "$stock_apk_to_patch" "lib/arm64-v8a/*" "lib/armeabi-v7a/*" "lib/x86/*" >/dev/null 2>&1 || :
			else
				zip -d "$stock_apk_to_patch" "lib/x86_64/*" "lib/x86/*" >/dev/null 2>&1 || :
			fi
		fi

		local apk_output="${BUILD_DIR}/${app_name_l}-${rv_brand_f}-v${version_f}-${arch_f}.apk"
		if [ "${NORB:-}" != true ] || { [ ! -f "$patched_apk" ] && [ ! -f "$apk_output" ]; }; then
			if ! patch_apk "$stock_apk_to_patch" "$patched_apk" "${patcher_args[*]}" "${args[cli]}" "${args[ptjar]}" "${args[ptjar_extra]:-}"; then
				epr "Building '${table}' failed!"
				break # 'break', not 'return', so that a mode which already shipped still records its state
			fi
		fi
		rm "$stock_apk_to_patch"
		if [ "$build_mode" = apk ]; then
			if [ "${NORB:-}" != true ] || { [ ! -f "$patched_apk" ] && [ ! -f "$apk_output" ]; }; then
				mv -f "$patched_apk" "$apk_output"
			else
				cp -f "$patched_apk" "$apk_output"
			fi
			pr "Built ${table} (non-root): '${apk_output}'"
			built_ok=true
			continue
		fi
		local base_template
		base_template=$(mktemp -d -p "$TEMP_DIR")
		cp -a $MODULE_TEMPLATE_DIR/. "$base_template"
		local upj # keep in sync with build.sh --list-update-jsons, which uses the same slug helper
		upj=$(update_json_name "$table")

		module_config "$base_template" "$pkg_name" "$version" "$arch"

		local patches_ver="${patches_jar##*-}"
		module_prop \
			"${args[module_prop_name]}" \
			"${app_name} ${args[rv_brand]}" \
			"${version} (patches ${patches_ver})" \
			"${app_name} ${args[rv_brand]} module" \
			"https://raw.githubusercontent.com/${GITHUB_REPOSITORY-}/update/${upj}" \
			"$base_template"

		local module_output="${app_name_l}-${rv_brand_f}-module-v${version_f}-${arch_f}.zip"
		pr "Packing module ${table}"
		cp -f "$patched_apk" "${base_template}/base.apk"

		if [ "${args[include_stock]}" != "disable" ]; then
			mkdir -p "${base_template}/stock/"
			local stock_mode="${args[include_stock]}"
			# 'auto' keeps the original developer signature where the source permits it. A bundle
			# source leaves a "${stock_apk}.apkm" beside the merged and re-signed apk. Install the
			# original signed splits from it, because a build with no merge keeps the signature.
			# A single-apk source is never merged or re-signed, so "$stock_apk" is already
			# original. Ship it without a change, as 'merged'.
			if [ "$stock_mode" = auto ]; then
				if [ -f "${stock_apk}.apkm" ]; then stock_mode=split; else stock_mode=merged; fi
			fi
			if [ "$stock_mode" = "merged" ]; then
				cp -f "$stock_apk" "${base_template}/stock/base.apk"
			elif [ "$stock_mode" = "split" ]; then
				if [ ! -f "${stock_apk}.apkm" ]; then
					epr "Cannot include as 'split' because stock apk of $table_name is not a bundle"
					break # 'break', not 'return', so that a mode which already shipped still records its state
				fi
				if [ "$arch" = "arm64-v8a" ]; then
					unzip -j "${stock_apk}.apkm" '*.apk' -x '*x86_64.apk' -x '*x86.apk' -x '*armeabi_v7a.apk' -d "${base_template}/stock/" >/dev/null 2>&1
				elif [ "$arch" = "arm-v7a" ]; then
					unzip -j "${stock_apk}.apkm" '*.apk' -x '*x86_64.apk' -x '*x86.apk' -x '*arm64_v8a.apk' -d "${base_template}/stock/" >/dev/null 2>&1
				elif [ "$arch" = "x86" ]; then
					unzip -j "${stock_apk}.apkm" '*.apk' -x '*x86_64.apk' -x '*arm64_v8a.apk' -x '*armeabi_v7a.apk' -d "${base_template}/stock/" >/dev/null 2>&1
				elif [ "$arch" = "x86_64" ]; then
					unzip -j "${stock_apk}.apkm" '*.apk' -x '*x86.apk' -x '*arm64_v8a.apk' -x '*armeabi_v7a.apk' -d "${base_template}/stock/" >/dev/null 2>&1
				else
					unzip -j "${stock_apk}.apkm" '*.apk' -x '*x86_64.apk' -x '*x86.apk' -d "${base_template}/stock/" >/dev/null 2>&1
				fi
			fi
		fi

		pushd >/dev/null "$base_template" || abort "Module template dir not found"
		zip -"$COMPRESSION_LEVEL" -FSqr "${CWD}/${BUILD_DIR}/${module_output}" .
		popd >/dev/null || :
		pr "Built ${table} (root): '${BUILD_DIR}/${module_output}'"
		built_ok=true
	done

	# Record the patch bundles that built this app. The key is the base table name, because
	# args[table_base] has no arch suffix. config_update then skips the app until a bundle changes.
	if [ "$built_ok" = true ]; then
		# The version line for the release notes in build.md. It is written now, after an artifact
		# exists, so a failed build never enters the release notes without an APK or a module. The
		# "Patches:" changelog part for each source is written earlier by get_prebuilts, but
		# build.sh emits only the parts whose source appears in built-patches.tsv. The line below
		# adds the source on success, so the bundle of a failed build also stays out.
		log "${table}: ${version}"
		log_built_patches "${args[table_base]}" "${args[patches_src]}" "${args[ptjar]}"
		if [ -n "${args[ptjar_extra]:-}" ]; then
			log_built_patches "${args[table_base]}" "${args[extra_patches_src]}" "${args[ptjar_extra]}"
		fi
	else
		# The build loop ran, but it made no artifact. A patch step or a packaging step broke out.
		record_failure "$table" "patching/packaging failed (${version})"
	fi
}

list_args() { tr -d '\t\r' <<<"$1" | tr -s ' ' | sed 's/" "/"\n"/g' | sed 's/\([^"]\)"\([^"]\)/\1'\''\2/g' | grep -v '^$' || :; }
join_args() { list_args "$1" | sed "s/^/${2} /" | paste -sd " " - || :; }

module_config() {
	local ma=""
	if [ "$4" = "arm64-v8a" ]; then
		ma="arm64"
	elif [ "$4" = "arm-v7a" ]; then
		ma="arm"
	fi
	echo "PKG_NAME=$2
PKG_VER=$3
MODULE_ARCH=$ma" >"$1/config"
}
module_prop() {
	echo "id=${1}
name=${2}
version=v${3}
versionCode=${NEXT_VER_CODE}
author=Andrew Liang
description=${4}" >"${6}/module.prop"

	if [ "$ENABLE_MODULE_UPDATE" = true ]; then echo "updateJson=${5}" >>"${6}/module.prop"; fi
}
