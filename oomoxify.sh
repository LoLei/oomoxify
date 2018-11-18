#!/usr/bin/env bash
# shellcheck disable=SC2115
set -ueo pipefail

root="$(readlink -f $(dirname "$0"))"
SRC_PATH=${root}


spotify_apps_path="/usr/share/spotify/Apps"
backup_dir="${HOME}/.config/oomox/spotify_backup"


print_usage() {
	echo "
usage:
$0 [-s /path/to/spotify/Apps] [-f FONT] PRESET_NAME_OR_PATH

options:
	-s, --spotify-apps-path		path to spotify/Apps
	-f \"FONT\", --font \"FONT\"	use \"FONT\"
	-w, --font-weight		'normalize' font weight
	-g, --gui			use polkit or 'gksu' instead of sudo

examples:
	$0 monovedek
	$0 -f \"Fantasque Sans Mono\" ./colors/gnome-colors/shiki-noble
	$0 -o /opt/spotify/Apps ./colors/retro/twg"
	exit 1
}


darker() {
	${root}/scripts/darker.sh $@
}
is_dark() {
	${root}/scripts/is_dark.sh $@
}

debug="0"


while [[ $# > 0 ]]
do
	case ${1} in
		-h|--help)
			print_usage
			exit 0
		;;
		-f|--font)
			replace_font="${2}"
			shift
			if [[ ! ${replace_font} = "sans-serif" ]] && \
			   [[ ! ${replace_font} = "serif" ]] && \
			   [[ ! ${replace_font} = "monospace" ]] && \
			   [[ ! $(grep '"' <<< ${replace_font}) ]] \
			; then
				replace_font='"'${replace_font}'"'
			fi
		;;
		-w|--font-weight)
			fix_font_weight="True"
		;;
		-g|--gui)
			gui="True"
		;;
		-d|--debug)
			debug="${2}"
			shift
		;;
		-s|--spotify-apps-path)
			spotify_apps_path="${2}"
			shift
		;;
		*)
			if [[ "${1}" == -* ]] || [[ ${THEME-} ]]; then
				echo "unknown option ${1}"
				print_usage
				exit 2
			fi
			THEME="${1}"
		;;
	esac
	shift
done

if [[ -z "${THEME:-}" ]] ; then
	print_usage
fi

if [[ ${THEME} == */* ]] || [[ ${THEME} == *.* ]] ; then
	source "$THEME"
	THEME=$(basename ${THEME})
else
	source "${root}/colors/$THEME"
fi

SPOTIFY_PROTO_BG="${SPOTIFY_PROTO_BG-$MENU_BG}"
SPOTIFY_PROTO_FG="${SPOTIFY_PROTO_FG-$MENU_FG}"
SPOTIFY_PROTO_SEL="${SPOTIFY_PROTO_SEL-$SEL_BG}"

main_bg="${SPOTIFY_MAIN_BG-$SPOTIFY_PROTO_BG}"

fg_is_dark=0
is_dark ${SPOTIFY_PROTO_FG} || fg_is_dark=$?
if [[ ${fg_is_dark} -eq 0 ]] ; then
	area_bg="${SPOTIFY_AREA_BG-$(darker ${SPOTIFY_PROTO_BG} -10)}"
	selected_row_bg_fallback="$(darker ${area_bg} -8)"
	selected_area_bg_fallback="$(darker ${area_bg} -14)"
	main_fg_fallback="$(darker ${SPOTIFY_PROTO_FG} -18)"
	accent_fg_fallback="$(darker ${SPOTIFY_PROTO_FG} 36)"
else
	area_bg="${SPOTIFY_AREA_BG-$(darker ${SPOTIFY_PROTO_BG})}"
	selected_row_bg_fallback="$(darker  ${area_bg} -20)"
	selected_area_bg_fallback="$(darker ${area_bg} -28)"
	main_fg_fallback="$(darker ${SPOTIFY_PROTO_FG} 18)"
	accent_fg_fallback="$(darker ${SPOTIFY_PROTO_FG} -36)"
fi
selected_row_bg="${SPOTIFY_SELECTED_ROW_BG-$selected_row_bg_fallback}"
selected_area_bg="${SPOTIFY_SELECTED_AREA_BG-$selected_area_bg_fallback}"
sidebar_fg="${SPOTIFY_SIDEBAR_FG-$SPOTIFY_PROTO_FG}"
main_fg="${SPOTIFY_MAIN_FG-$main_fg_fallback}"
accent_fg="${SPOTIFY_ACCENT_FG-$accent_fg_fallback}"

hover_text="${SPOTIFY_HOVER_TEXT-$SPOTIFY_PROTO_SEL}"
selected_text_color="${SPOTIFY_SELECTED_TEXT_COLOR-$SPOTIFY_PROTO_SEL}"
selected_button_color_fallback="${SPOTIFY_PROTO_SEL}"
hover_selection_color_fallback="$(darker ${SPOTIFY_PROTO_SEL} -25)"
pressed_selection_color_fallback="$(darker ${SPOTIFY_PROTO_SEL} 20)"
selected_button_color="${SPOTIFY_SELECTED_BUTTON_COLOR-$selected_button_color_fallback}"
hover_selection_color="${SPOTIFY_HOVER_SELECTION_COLOR-$hover_selection_color_fallback}"
pressed_selection_color="${SPOTIFY_PRESSED_SELECTION_COLOR-$pressed_selection_color_fallback}"

blue_blocks_color="${SPOTIFY_BLUE_BLOCKS-$BTN_BG}"
blue_blocks_hover_color="$(darker ${blue_blocks_color} -15)"

#top_and_button_bg="${SPOTIFY_TOP_AND_BTN_BG-$BTN_BG}"
top_and_button_bg="${SPOTIFY_TOP_BTN_BG-$main_bg}"
cover_overlay_color="$(${root}/scripts/hex_to_rgba.sh ${main_bg} 0.55)"


tmp_dir="$(mktemp -d)"
output_dir="$(mktemp -d)"
log_file=$(mktemp)
function post_clean_up {
	rm -r "${tmp_dir}" || true
	rm -r "${output_dir}" || true
	rm "${log_file}" || true
}
trap post_clean_up EXIT SIGHUP SIGINT SIGTERM

backup_file="${backup_dir}/version.txt"
spotify_version=$(spotify --version 2>&1 | grep "^Spotify" | cut -d' ' -f3 | tr -d ',')
spotify_version_in_backup=$(cat "${backup_file}" || true)
if [[ $spotify_version != $spotify_version_in_backup ]] ; then
	if [[ -d "${backup_dir}" ]] ; then
		rm -r "${backup_dir}"
	fi
fi
if [[ ! -d "${backup_dir}" ]] ; then
	mkdir "${backup_dir}"
	cp -prf "${spotify_apps_path}"/*.spa "${backup_dir}/"
	echo "${spotify_version}" > "${backup_file}"
fi

cd "${root}"
for file in $(ls "${backup_dir}"/*.spa) ; do
	filename="$(basename "${file}")"
	echo "${filename}"
	cp "${file}" "${tmp_dir}/"
	cd "${tmp_dir}"
	unzip "./${filename}" > /dev/null
	if [[ -d ./css/ ]] ; then
		for css in $(ls ./css/*.css); do
			if [ ! -z "${THEME:-}" ] ; then
			sed -i \
				-e "s/1ed660/oomox_selected_text_color/gI" \
				-e "s/1ed760/oomox_selected_text_color/gI" \
				-e "s/1db954/oomox_hover_selection_color/gI" \
				-e "s/1df369/oomox_hover_selection_color/gI" \
				-e "s/1df269/oomox_hover_selection_color/gI" \
				-e "s/1cd85e/oomox_hover_selection_color/gI" \
				-e "s/1bd85e/oomox_hover_selection_color/gI" \
				-e "s/18ac4d/oomox_selected_button_color/gI" \
				-e "s/18ab4d/oomox_selected_button_color/gI" \
				-e "s/179443/oomox_pressed_selection_color/gI" \
				-e "s/14833B/oomox_pressed_selection_color/gI" \
				\
				-e "s/282828/oomox_main_bg/g" \
				-e "s/121212/oomox_main_bg/g" \
				-e "s/rgba(18, 18, 18, [0-9\.]\+)/#oomox_main_bg/g" \
				-e "s/181818/oomox_area_bg/g" \
				-e "s/rgba(18,19,20,[0-9\.]\+)/#oomox_area_bg/g" \
				-e "s/000000/oomox_area_bg/g" \
				-e "s/333333/oomox_selected_row_bg/g" \
				-e "s/3f3f3f/oomox_selected_row_bg/g" \
				-e "s/535353/oomox_selected_row_bg/g" \
				-e "s/404040/oomox_selected_area_bg/g" \
				-e "s/rgba(80,55,80,[0-9\.]\+)/#oomox_area_bg/g" \
				-e "s/rgba(40, 40, 40, [0-9\.]\+)/#oomox_area_bg/g" \
				-e "s/rgba(40,40,40,[0-9\.]\+)/#oomox_area_bg/g" \
				-e "s/rgba(24, 24, 24, 0)/#oomox_area_bg/g" \
				-e "s/rgba(24, 24, 24, 0\.[6,8])/#oomox_area_bg/g" \
				-e "s/rgba(18, 19, 20, [0-9\.]\+)/#oomox_area_bg/g" \
				-e "s/#000011/#oomox_area_bg/g" \
				-e "s/#0a1a2d/#oomox_area_bg/g" \
				\
				-e "s/ffffff/oomox_accent_fg/gI" \
				-e "s/f8f8f7/oomox_hover_text/gI" \
				-e "s/fcfcfc/oomox_hover_text/gI" \
				-e "s/d9d9d9/oomox_hover_text/gI" \
				-e "s/adafb2/oomox_sidebar_fg/gI" \
				-e "s/c8c8c8/oomox_sidebar_fg/gI" \
				-e "s/a0a0a0/oomox_sidebar_fg/gI" \
				-e "s/bec0bb/oomox_sidebar_fg/gI" \
				-e "s/bababa/oomox_sidebar_fg/gI" \
				-e "s/b3b3b3/oomox_sidebar_fg/gI" \
				-e "s/rgba(179, 179, 179, [0-9\.]\+)/#oomox_sidebar_fg/g" \
				-e "s/cccccc/oomox_main_fg/gI" \
				-e "s/ededed/oomox_main_fg/gI" \
				\
				-e "s/4687d6/oomox_blue_blocks/gI" \
				-e "s/rgba(70, 135, 214, [0-9\.]\+)/#oomox_blue_blocks/g" \
				-e "s/2e77d0/oomox_blue_blocks_hover/gI" \
				-e "s/rgba(51,153,255,[0-9\.]\+)/#oomox_blue_blocks_hover/g" \
				-e "s/rgba(30,50,100,[0-9\.]\+)/#oomox_blue_blocks_hover/g" \
				\
				-e "s/rgba(24, 24, 24, [0-9\.]\+)/#oomox_top_and_button_bg/g" \
				-e "s/rgba(25,20,20,[0-9\.]\+)/#oomox_top_and_button_bg/g" \
				-e "s/rgba(160, 160, 160, [0-9\.]\+)/#oomox_main_fg/g" \
				-e "s/rgba(255, 255, 255, ...)/#oomox_main_fg/gI" \
				-e "s/#ddd;/#oomox_main_fg;/g" \
				-e "s/#000;/#oomox_area_bg;/g" \
				-e "s/#000 /#oomox_area_bg /g" \
				-e "s/#333;/#oomox_selected_row_bg;/gI" \
				-e "s/#333 /#oomox_selected_row_bg /gI" \
				-e "s/#444;/#oomox_selected_area_bg;/gI" \
				-e "s/#444 /#oomox_selected_area_bg /gI" \
				-e "s/#fff;/#oomox_accent_fg;/gI" \
				-e "s/#fff /#oomox_accent_fg /gI" \
				-e "s/ black;/ #oomox_area_bg;/g" \
				-e "s/ black / #oomox_area_bg /g" \
				-e "s/ gray / #oomox_main_bg /g" \
				-e "s/ gray;/ #oomox_main_bg;/g" \
				-e "s/ lightgray / #oomox_main_fg /g" \
				-e "s/ lightgray;/ #oomox_main_fg;/g" \
				-e "s/ white;/ #oomox_accent_fg;/gI" \
				-e "s/ white / #oomox_accent_fg /gI" \
				\
				-e "s/rgba(0, 0, 0, [0-9\.]\+)/oomox_cover_overlay/g" \
				-e "s/rgba(0,0,0,[0-9\.]\+)/oomox_cover_overlay/g" \
				\
				-e "s/#fff/#oomox_accent_fg/gI" \
				-e "s/#000/#oomox_area_bg/gI" \
				-e "s/border-radius[: ]\+500px/border-radius:${ROUNDNESS}px/gI" \
				"${css}"
			if [[ $debug != '0' && $(grep "${debug}" "${css}") ]] >/dev/null ; then
				echo '-------------------------------------------'
				echo " -- ${css}"
				grep -B 3 -A 8 -i "${debug}" "${css}" || true
			fi
			sed -i \
				-e "s/oomox_cover_overlay/${cover_overlay_color}/g" \
				-e "s/oomox_top_and_button_bg/${top_and_button_bg}/g" \
				-e "s/oomox_main_bg/${main_bg}/g" \
				-e "s/oomox_area_bg/${area_bg}/g" \
				-e "s/oomox_selected_row_bg/${selected_row_bg}/g" \
				-e "s/oomox_selected_area_bg/${selected_area_bg}/g" \
				-e "s/oomox_accent_fg/${accent_fg}/gI" \
				-e "s/oomox_hover_text/${hover_text}/gI" \
				-e "s/oomox_selected_text_color/${selected_text_color}/gI" \
				-e "s/oomox_selected_button_color/${selected_button_color}/gI" \
				-e "s/oomox_hover_selection_color/${hover_selection_color}/gI" \
				-e "s/oomox_pressed_selection_color/${pressed_selection_color}/gI" \
				-e "s/oomox_main_fg/${main_fg}/gI" \
				-e "s/oomox_sidebar_fg/${sidebar_fg}/gI" \
				-e "s/oomox_blue_blocks/${blue_blocks_color}/gI" \
				-e "s/oomox_blue_blocks_hover/${blue_blocks_hover_color}/gI" \
				"${css}"
			fi
			echo "
			.SearchInput__input {
				background-color: #${area_bg} !important;
				color: #${main_fg} !important;
			}
			input, .button, button, button *, .button * {
				border-radius: ${ROUNDNESS}px !important;
			}
			" >> "${css}"
			if [ ! -z "${replace_font:-}" ] ; then
				echo "
				* {
					font-family: ${replace_font} !important;
					font-weight: 400 !important;
				}
				" >> "${css}"
			fi
			if [ ! -z "${fix_font_weight:-}" ] && [ -z "${replace_font:-}" ] ; then
				echo "
				* {
					font-weight: 400 !important;
				}
				" >> "${css}"
			fi
			zip -0 "./${filename}" "${css}" > /dev/null
		done
		cd "${tmp_dir}"
		mv "./${filename}" "${output_dir}/"
	fi
	rm "${tmp_dir}/"* -r
done

PKEXEC="pkexec --disable-internal-agent"
if [ ! -z "${gui:-}" ] ; then
	if [ "$(which pkexec)" ] ; then
		priv_tool=${PKEXEC}
	else
		priv_tool="gksu"
	fi
else
	priv_tool="sudo"
fi

fails_counter=0
while true; do
	exit_code=0
	${priv_tool} cp "${output_dir}/"* "${spotify_apps_path}"/ 2>&1 | tee ${log_file} || exit_code=$?
	if [ $exit_code -ne 0 ] ; then
		if [ "${priv_tool}" = "${PKEXEC}" ] && [ "$(grep "No authentication agent found." ${log_file})" ] ; then
			priv_tool="gksu"
		else
			fails_counter=$((fails_counter + 1))
		fi
		if [ ${fails_counter} -gt 3 ] ; then
			break
		fi
	else
		break
	fi
done
exit ${exit_code}
