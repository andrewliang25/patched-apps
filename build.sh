#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

source utils.sh

trap "abort" INT

if [ "${1-}" = "clean" ]; then
	rm -rf "$TEMP_DIR" "$BUILD_DIR" build.md "$BUILT_PATCHES_FILE" "$FAILED_BUILDS_FILE" "$BUILD_WARNINGS_FILE"
	exit 0
fi

jq --version >/dev/null || abort "\`jq\` is not installed. install it with 'apt install jq' or equivalent"
java --version >/dev/null || abort "\`java\` is not installed. install it with 'apt install openjdk-21-jre' or equivalent"
zip --version >/dev/null || abort "\`zip\` is not installed. install it with 'apt install zip' or equivalent"

set_prebuilts

vtf() { if ! isoneof "${1}" "true" "false"; then abort "ERROR: '${1}' is not a valid option for '${2}': only true or false is allowed"; fi; }

# -- Main config --
toml_prep "${1:-config.toml}" || abort "could not find config file '${1:-config.toml}'\n\tUsage: $0 <config.toml>"
main_config_t=$(toml_get_table_main)
COMPRESSION_LEVEL=$(toml_get "$main_config_t" compression-level) || COMPRESSION_LEVEL="9"
if ! PARALLEL_JOBS=$(toml_get "$main_config_t" parallel-jobs); then
	if [ "$OS" = Android ]; then PARALLEL_JOBS=1; else PARALLEL_JOBS=$(nproc); fi
fi
PARALLEL_JOBS=1 # TODO: multiple jobs were broken by recent cli versions. and i cant bother to fix it so instead, i disable it.
REMOVE_RV_INTEGRATIONS_CHECKS=$(toml_get "$main_config_t" remove-rv-integrations-checks) || REMOVE_RV_INTEGRATIONS_CHECKS="true"
DEF_PATCHES_VER=$(toml_get "$main_config_t" patches-version) || DEF_PATCHES_VER="latest"
DEF_CLI_VER=$(toml_get "$main_config_t" cli-version) || DEF_CLI_VER="latest"
DEF_PATCHES_SRC=$(toml_get "$main_config_t" patches-source) || DEF_PATCHES_SRC="ReVanced/revanced-patches"
DEF_CLI_SRC=$(toml_get "$main_config_t" cli-source) || DEF_CLI_SRC="ReVanced/revanced-cli"
DEF_RV_BRAND=$(toml_get "$main_config_t" rv-brand) || DEF_RV_BRAND="ReVanced"
mkdir -p "$TEMP_DIR" "$BUILD_DIR"

if [ "${2-}" = "--config-update" ]; then
	config_update
	exit 0
fi

# print the *-update.json basenames every module-producing table should own, so
# CI can prune orphans left behind by renames / build-mode switches. Config-driven
# (not this-run's built subset) and independent of 'enabled' so a disabled-but-still
# -configured module keeps its json.
if [ "${2-}" = "--list-update-jsons" ]; then
	for table_name in $(toml_get_table_names); do
		[ -z "$table_name" ] && continue
		t=$(toml_get_table "$table_name")
		bm=$(toml_get "$t" build-mode) || bm=apk # app-table only, default apk (as the main loop below)
		case "$bm" in both | module) ;; *) continue ;; esac
		# mirror the arch fan-out below: arch=both builds one module (hence one update
		# json) per ABI, with the arch folded into the table name build_rv slugifies.
		arch=$(toml_get "$t" arch) || arch=all
		if [ "$arch" = both ]; then
			update_json_name "$table_name (arm64-v8a)"
			update_json_name "$table_name (arm-v7a)"
		else
			update_json_name "$table_name"
		fi
	done
	exit 0
fi

: >build.md
rm -f "$BUILT_PATCHES_FILE" "$TEMP_DIR"/built-patches.tsv # stale from a previous run
ENABLE_MODULE_UPDATE=$(toml_get "$main_config_t" enable-module-update) || ENABLE_MODULE_UPDATE=true
if [ "$ENABLE_MODULE_UPDATE" = true ] && [ -z "${GITHUB_REPOSITORY-}" ]; then
	pr "You are building locally. Module updates will not be enabled."
	ENABLE_MODULE_UPDATE=false
fi
if ((COMPRESSION_LEVEL > 9)) || ((COMPRESSION_LEVEL < 0)); then abort "compression-level must be within 0-9"; fi

rm -rf module/bin/*/tmp.*
rm -rf "$TEMP_DIR"/changelogs # per-source changelog fragments, rebuilt this run by get_prebuilts
rm -f "$TEMP_DIR"/cli-changelog.md
rm -f "$FAILED_BUILDS_FILE" "$BUILD_WARNINGS_FILE" # stale failures/warnings from a previous local run

mkdir -p ${MODULE_TEMPLATE_DIR}/bin/arm64 ${MODULE_TEMPLATE_DIR}/bin/arm ${MODULE_TEMPLATE_DIR}/bin/x86 ${MODULE_TEMPLATE_DIR}/bin/x64
gh_dl "${MODULE_TEMPLATE_DIR}/bin/arm64/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-arm64-v8a"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/arm/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-armeabi-v7a"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/x86/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-x86"
gh_dl "${MODULE_TEMPLATE_DIR}/bin/x64/cmpr" "https://github.com/j-hc/cmpr/releases/latest/download/cmpr-x86_64"

idx=0
for table_name in $(toml_get_table_names); do
	if [ -z "$table_name" ]; then continue; fi
	t=$(toml_get_table "$table_name")
	enabled=$(toml_get "$t" enabled) || enabled=true
	vtf "$enabled" "enabled"
	if [ "$enabled" = false ]; then continue; fi
	if ((idx >= PARALLEL_JOBS)); then
		wait -n
		idx=$((idx - 1))
	fi

	declare -A app_args
	patches_src=$(toml_get "$t" patches-source) || patches_src=$DEF_PATCHES_SRC
	patches_ver=$(toml_get "$t" patches-version) || patches_ver=$DEF_PATCHES_VER
	cli_src=$(toml_get "$t" cli-source) || cli_src=$DEF_CLI_SRC
	cli_ver=$(toml_get "$t" cli-version) || cli_ver=$DEF_CLI_VER

	if ! PREBUILTS="$(get_prebuilts "$cli_src" "$cli_ver" "$patches_src" "$patches_ver")"; then
		epr "Could not get prebuilts"
		continue
	fi
	read -r patches_jar cli_jar <<<"$PREBUILTS"
	app_args[cli]=$cli_jar
	app_args[ptjar]=$patches_jar
	app_args[patches_src]=$patches_src # recorded (with the built asset) into the patches state

	# optional second patch bundle applied alongside the primary one (e.g. x-shim + Piko).
	# reuses get_prebuilts (handles gitlab:/GitHub + integrations stripping); the CLI is cached
	# from the call above so it isn't re-downloaded. its 'Patches:' changelog line in build.md
	# also lets config_update detect updates to this bundle.
	extra_patches_src=$(toml_get "$t" extra-patches-source) && {
		extra_patches_ver=$(toml_get "$t" extra-patches-version) || extra_patches_ver="latest"
		if ! EXTRA="$(get_prebuilts "$cli_src" "$cli_ver" "$extra_patches_src" "$extra_patches_ver")"; then
			epr "Could not get extra prebuilts"
			continue
		fi
		read -r extra_patches_jar _ <<<"$EXTRA"
		app_args[ptjar_extra]=$extra_patches_jar
		app_args[extra_patches_src]=$extra_patches_src
	} || {
		app_args[ptjar_extra]=""
		app_args[extra_patches_src]=""
	}
	app_args[rv_brand]=$(toml_get "$t" rv-brand) || app_args[rv_brand]=$DEF_RV_BRAND

	app_args[excluded_patches]=$(toml_get "$t" excluded-patches) || app_args[excluded_patches]=""
	if [ -n "${app_args[excluded_patches]}" ] && [[ ${app_args[excluded_patches]} != *'"'* ]]; then abort "patch names inside excluded-patches must be quoted"; fi
	app_args[included_patches]=$(toml_get "$t" included-patches) || app_args[included_patches]=""
	if [ -n "${app_args[included_patches]}" ] && [[ ${app_args[included_patches]} != *'"'* ]]; then abort "patch names inside included-patches must be quoted"; fi
	# (fork-specific) per-mode patch overrides: like YouTube's automatic GmsCore toggle, but
	# user-specified — include/exclude a patch only in apk mode or only in module mode from a
	# single 'both' table. Applied on top of the shared included/excluded-patches in build_rv.
	for _pm in apk module; do
		app_args[${_pm}_excluded_patches]=$(toml_get "$t" "${_pm}-excluded-patches") || app_args[${_pm}_excluded_patches]=""
		if [ -n "${app_args[${_pm}_excluded_patches]}" ] && [[ ${app_args[${_pm}_excluded_patches]} != *'"'* ]]; then abort "patch names inside ${_pm}-excluded-patches must be quoted"; fi
		app_args[${_pm}_included_patches]=$(toml_get "$t" "${_pm}-included-patches") || app_args[${_pm}_included_patches]=""
		if [ -n "${app_args[${_pm}_included_patches]}" ] && [[ ${app_args[${_pm}_included_patches]} != *'"'* ]]; then abort "patch names inside ${_pm}-included-patches must be quoted"; fi
	done
	app_args[exclusive_patches]=$(toml_get "$t" exclusive-patches) && vtf "${app_args[exclusive_patches]}" "exclusive-patches" || app_args[exclusive_patches]=false
	app_args[version]=$(toml_get "$t" version) || app_args[version]="auto"
	app_args[app_name]=$(toml_get "$t" app-name) || app_args[app_name]=$table_name
	app_args[patcher_args]=$(toml_get "$t" patcher-args) || app_args[patcher_args]=""
	app_args[clone]=$(toml_get "$t" clone) && vtf "${app_args[clone]}" "clone" || app_args[clone]=false
	app_args[table]=$table_name
	app_args[table_base]=$table_name # stable state key; app_args[table] gets an arch suffix below
	app_args[build_mode]=$(toml_get "$t" build-mode) && {
		if ! isoneof "${app_args[build_mode]}" both apk module; then
			abort "ERROR: build-mode '${app_args[build_mode]}' is not a valid option for '${table_name}': only 'both', 'apk' or 'module' is allowed"
		fi
	} || app_args[build_mode]=apk
	app_args[include_stock]=$(toml_get "$t" include-stock) && {
		if ! isoneof "${app_args[include_stock]}" disable merged split auto; then
			abort "ERROR: include-stock '${app_args[include_stock]}' is not a valid option for '${table_name}': only 'disable', 'merged', 'split' or 'auto' is allowed"
		fi
	} || app_args[include_stock]=merged

	for dl_from in "${DL_SRCS[@]}"; do
		if app_args[${dl_from}_dlurl]=$(toml_get "$t" "${dl_from}-dlurl"); then
			app_args[${dl_from}_dlurl]=${app_args[${dl_from}_dlurl]%/}
			app_args[${dl_from}_dlurl]=${app_args[${dl_from}_dlurl]%download}
			app_args[${dl_from}_dlurl]=${app_args[${dl_from}_dlurl]%/}
			app_args[dl_from]=${dl_from}
		else
			app_args[${dl_from}_dlurl]=""
		fi
	done
	if [ -z "${app_args[dl_from]-}" ]; then abort "ERROR: no 'dlurl' option was set for '$table_name'. (${DL_SRCS[*]})"; fi
	app_args[arch]=$(toml_get "$t" arch) || app_args[arch]="all"
	if ! isoneof "${app_args[arch]}" "both" "all" "arm64-v8a" "arm-v7a" "x86_64" "x86"; then
		abort "wrong arch '${app_args[arch]}' for '$table_name'"
	fi

	app_args[pkg_name]=$(toml_get "$t" pkg-name) || app_args[pkg_name]=""
	app_args[dpi]=$(toml_get "$t" dpi) || app_args[dpi]=""
	table_name_f=$(module_id_name "$table_name")
	app_args[module_prop_name]=$(toml_get "$t" module-prop-name) || app_args[module_prop_name]="${table_name_f}-andrew"
	if ! [[ ${app_args[module_prop_name]} =~ ^[a-zA-Z][a-zA-Z0-9._-]+$ ]]; then
		abort "invalid module id '${app_args[module_prop_name]}' for '$table_name' (magisk requires ^[a-zA-Z][a-zA-Z0-9._-]+\$)"
	fi

	if [ "${app_args[arch]}" = both ]; then
		app_args[table]="$table_name (arm64-v8a)"
		app_args[arch]="arm64-v8a"
		module_prop_name_b=${app_args[module_prop_name]}
		app_args[module_prop_name]="${module_prop_name_b}-arm64"
		idx=$((idx + 1))
		build_rv "$(declare -p app_args)" &
		app_args[table]="$table_name (arm-v7a)"
		app_args[arch]="arm-v7a"
		app_args[module_prop_name]="${module_prop_name_b}-arm"
		if ((idx >= PARALLEL_JOBS)); then
			wait -n
			idx=$((idx - 1))
		fi
		idx=$((idx + 1))
		build_rv "$(declare -p app_args)" &
	else
		if [ "${app_args[arch]}" = "arm64-v8a" ]; then
			app_args[module_prop_name]="${app_args[module_prop_name]}-arm64"
		elif [ "${app_args[arch]}" = "arm-v7a" ]; then
			app_args[module_prop_name]="${app_args[module_prop_name]}-arm"
		fi
		idx=$((idx + 1))
		build_rv "$(declare -p app_args)" &
	fi
done
wait
_clean_tmp
if [ -s "$FAILED_BUILDS_FILE" ]; then
	epr "$(($(wc -l <"$FAILED_BUILDS_FILE"))) app(s) failed to build:"
	while IFS=$'\t' read -r t r; do epr "  - ${t}: ${r}"; done <"$FAILED_BUILDS_FILE"
fi
if [ -s "$BUILD_WARNINGS_FILE" ]; then
	wpr "$(($(wc -l <"$BUILD_WARNINGS_FILE"))) app(s) built with warnings:"
	while IFS=$'\t' read -r t r; do wpr "  - ${t}: ${r}"; done <"$BUILD_WARNINGS_FILE"
fi
if [ -z "$(ls -A1 "${BUILD_DIR}")" ]; then abort "All builds failed."; fi

# fold this run's successfully-built bundles into a per-run JSON ({ "<app>": { "<src>": "<asset>" } }).
# build.yml merges this into the persistent PATCHES_STATE_FILE on the 'update' branch, so apps
# built in an earlier run keep their record instead of being clobbered like build.md is.
if [ -f "$TEMP_DIR"/built-patches.tsv ]; then
	jq -Rn 'reduce (inputs | split("\t")) as $r ({}; .[$r[0]][$r[1]] = $r[2])' \
		"$TEMP_DIR"/built-patches.tsv >"$BUILT_PATCHES_FILE"
fi

log "\nInstall [MicroG-RE](https://github.com/MorpheApp/MicroG-RE/releases) for non-root Google APKs"
log "Use [zygisk-detach](https://github.com/j-hc/zygisk-detach) to detach patched apps from Play Store"
log "\nRepository: [Patched Apps](https://github.com/andrewliang25/patched-apps)"
log "\nEvery APK/module is published with [GitHub build provenance attestations](https://docs.github.com/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds) — verify a downloaded file with the [GitHub CLI](https://cli.github.com):"
log '```'
log "gh attestation verify <file> --repo andrewliang25/patched-apps"
log '```'
# emit changelog fragments only for patch sources that actually shipped (built-patches.tsv is
# written on success only), so a failed build's bundle never advertises a patch update. dedup the
# source column preserving first-seen order; cli-changelog.md is appended last as before.
cl_files=()
if [ -f "$TEMP_DIR"/built-patches.tsv ]; then
	while IFS= read -r built_src; do
		built_cl=$(cl_changelog_file "$built_src")
		[ -f "$built_cl" ] && cl_files+=("$built_cl")
	done < <(cut -f2 "$TEMP_DIR"/built-patches.tsv | awk '!seen[$0]++')
fi
log "$(cat "${cl_files[@]}" "$TEMP_DIR"/cli-changelog.md 2>/dev/null)"

pr "Done"
