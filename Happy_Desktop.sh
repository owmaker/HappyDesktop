#!/bin/bash
# 
#   copyright © 2017 retiredbutstillhavingfun
#   copyright © 2025 owmaker
#
#   Happy Desktop
#   Version 2.00
#   10OCT2017
#   drm200@free.fr
#
#
#### Program Requirements: #####
#  This program is used to save/restore/align the Ubuntu and Mint Desktop icons
#  positions when Nautilus, Nemo, or Caja is managing the desktop.
#  This version has been tested with
#     Mint 22.1 Mate with Caja
#	
#   Requirements:
#     gio which is used by Nautilus, Nemo & Caja to store icon positions
#     Nautilus or Nemo or Caja is your file manager
#     bash, zenity, gsettings, xprop, sed, grep
#
#

### Definition of constants #####
#!/bin/bash
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE is a relative symlink, resolve it
done
script_path="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

#exec 5> "$script_path"/debug_output.txt
#BASH_XTRACEFD="5"
#set -x
#PS4='$LINENO: '

# desktop_path="$(eval echo ~$USER)/Desktop" # must NOT end with backslash
desktop_path="$(eval xdg-user-dir DESKTOP)" #changed to handle "desktop" in other languages
desktop_file=$desktop_path/"Happy Desktop.desktop"
restore_file="$script_path/happy_desktop_restore.dat"
undo_file="$script_path/happy_desktop_undo.dat"
ini_file="$script_path/happy_desktop.ini"
lang_file="$script_path/happy_desktop_lang"
title_text="Happy Desktop"
x_min=0 # x-axis icon canvas offset .. for values below this the icon fails to move left
this_script_name=$(basename "${BASH_SOURCE[0]}")
sure_name="$script_path/$this_script_name"
undo_ini=''
undo_enabled=1
#tmp_file="$script_path/tmp_file.db"


### functions #####

# tests for positive integer
# arguments $arg_to_test
is_integer ()
{
[[ $1 =~ ^[0-9]+$ ]]
return "$?"
}


display_sys_info ()
{
local msg="System: $my_distro_long
Desktop: $DESKTOP_SESSION
Desktop Mgr: $my_desktop_manager
Screen: $screen_width x $screen_height
Icon Zoom: $icon_zoom\\%

Canvas: $x_max x $y_max
Grid: $grid_width x $grid_height
Top Margin: $top_margin
Left Margin: $left_margin"
zenity --info --no-wrap --title="System Information" --text="$msg"
}



get_screen_data ()
{
local available_screen
available_screen=$(xprop -root | grep -e 'NET_WORKAREA(CARDINAL)') #get available screen dimensions
available_screen=${available_screen##*=} #strip off beginning text
echo "$available_screen"
return 0
}

create_desktop_icon()
{
local msg=${lang[msg8]}
[ -f "$desktop_file" ] && msg="$msg\\n\\n${lang[msg13]}"
if ! zenity --question --no-wrap --text="\\n$msg?"; then return 1; fi
[ -f "$desktop_file" ] && rm "$desktop_file"
temp="#!/usr/bin/env xdg-open
[Desktop Entry]
Name=Happy Desktop
Comment=Organize, Save and Restore your desktop icons
Keywords=icons;desktop
Exec=\"$script_path/Happy_Desktop.sh\"
Icon=$script_path/Happy_Desktop.png
Terminal=false
Type=Application
StartupNotify=false"
echo -e "$temp" > "$desktop_file" || return 1
chmod +x "$desktop_file"
return "$?"
}

read_text()
{
local line
local start=0
local ret=""
while read -r line; do
	if [ "${line}" == "$2" ]; then start=2; fi
	if [ $start -eq 1 ]; then ret="$ret\\n${line:1}"; fi
	if [ "${line}" == "$1" ]; then start=1; fi
done < "$sure_name"
echo "$ret"
}


display_help()
{
local help_txt
help_txt=$(read_text "#done" "#gnu_text")
echo -e "$help_txt" | zenity --text-info --cancel-label="${lang[pb_return]}" \
--font="tahoma" --title="     $title_text ${lang[main5]} " --width $((screen_width / 2)) --height $((screen_height / 2))
}


about_this()
{
local gnu_txt
local about_txt
gnu_txt=$(read_text "#gnu_text" "end")
about_txt="<span background=\"#007f00\" font_desc=\"WebDings Italic 24\" foreground=\"#ff7f7f\" stretch=\"ultraexpanded\" underline=\"double\" variant=\"smallcaps\" weight=\"900\">  Happy Desktop  </span>\\n\\n<small>version 2.00\\n\\ncopyright © 2017 retiredbutstillhavingfun\\ndrm200@free.fr\\n$gnu_txt</small>"
zenity --info --no-wrap --title="$title_text" --text="$about_txt"
}



# Returns the icon positions
read_icon_positions ()
{
#Get current icon positions from gvfs-info
local line
local icon_name
local prefix_str
local position
local x_pos
local y_pos
local tmp=''
# IFS=  for not dropping trailing spaces in read
IFS=
while read -r line; do
	case "$line" in
		*"standard::name:"*) icon_name=${line#*name: };;
		*'metadata::'"$my_desktop_manager"'-icon-position:'*)
			prefix_str=${line%:*}
			prefix_str=$(echo "$prefix_str" | sed 's/^ *//')
			position=${line#*position: }
			x_pos=${position%,*}
			y_pos=${position#*,}
			if is_integer "$x_pos" && is_integer "$y_pos"; then
				tmp="$tmp\\n$icon_name|$x_pos|$y_pos|||$prefix_str"
			fi;;
	esac
done < <(gio info "$desktop_path"/* | grep -E 'standard::name:|icon-position:')
echo -e "$tmp" | sed '/^\s*$/d' | sort -t\| -k2g,2 -k3g,3
unset IFS
}


#              $1        $2
#arguments icon_data restore_file
create_restore_file ()
{
local icon_name
local prefix_str
local x_pos
local y_pos
local col
local row
local prefix_str
local tmp=''
IFS='|'
while read -r icon_name x_pos y_pos col row prefix_str; do
	tmp="$tmp"'\ngio set '\'"$desktop_path/$icon_name"\'" $prefix_str $x_pos,$y_pos"
done < <(echo -e "$1")
unset IFS
echo -e "$tmp" | sed '/^\s*$/d' > "$2"
}


#check for changes in screen resolution or icon scale since last run
check_for_screen_changes()
{
local msg
local dirty=1
if [ "$current_screen_width" -ne "$screen_width" ] || [ "$current_screen_height" -ne "$screen_height" ] ; then
	msg="${lang[msg9]}:\\n  $screen_width x $screen_height ${lang[msg10]}:\\n  $current_screen_width x $current_screen_height"
	warning_popup "$msg"
	screen_width=$current_screen_width
	screen_height=$current_screen_height
	dirty=0
fi
if [ "$current_zoom" -ne "$icon_zoom" ]; then
	msg="${lang[msg12]}:\\n  $icon_zoom ${lang[msg10]}:\\n  $current_zoom"
	warning_popup "$msg"
	icon_zoom=$current_zoom
	dirty=0
fi
if [ "$dirty" -eq 0 ]; then
	create_restore_file "$icon_data" "$restore_file"
	x_max=$(get_max "$screen_width" "$icon_zoom")
	y_max=$(get_max "$screen_height" "$icon_zoom")
	set_margins "$icon_data"
	write_ini
	restore_ini=$(cat "$ini_file")
fi
}


warning_popup ()
{
zenity --info --no-wrap --text="$1"
}

set_lang_default()
{
typeset -gA lang
lang=(
		[main1]="Save current icon positions"
		[main2]="Save icon positions to grid"
		[main3]="Restore icon positions"
		[main4]="Configuration"
		[main5]="Help"
		[main6]="About"
		[main7]="Select an item"
		[main8]="Undo the Last Operation"
		[main9]="Disentangle Overlapping Icons"
		[main10]="System Info"
		[pb_done]="Done"
		[pb_select]="Select"
		[pb_return]="Return"
		[pb_edit]="Edit"
		[pb_save]="Save"
		[pb_cancel]="Cancel"
		[pb_view]="View List"
		[config1]="Language"
		[config2]="Icons per row"
		[config3]="Icons per column"
		[config4]="Left Margin"
		[config5]="Top Margin"
		[config6]="Grid Width"
		[config7]="Grid Height"
		[config8]="Select an item"
		[msg1]="Icon positions saved"
		[msg2]="Icon positions restored"
		[msg3]="Undo operation completed"
		[msg4]="Enter new value for"
		[msg5]='Negative values are\n not allowed!'
		[msg6]="Values must be numbers ... Not text!"
		[msg7]='Icon positions updated'
		[msg8]='Would you like to create a desktop icon\nto launch the application?'
		[msg9]="Screen resolution has changed from"
		[msg10]="to"
		[msg11]="since the icon positions were last saved."
		[msg12]="The Desktop default icon zoom has changed from"
		[msg13]="This will overwrite the existing desktop icon"
		[msg14]="Initialization values must be provided!"
		[msg15]="Initialize Icon Spacing"
		[msg16]="Enter the values you desire: "
		[msg17]="Icon positions saved to grid"
		[msg18]="Aborting"
		[msg19]="Setting is too small"
		[msg20]="Setting is too large"
		[msg21]="Grid size is too small"
		[msg22]="The following icons failed to restore"
		[msg23]="Icon separation complete"
		[msg24]="Please make a selection!"
		[msg25]="Some Icons were not available to restore and were probably recently deleted"
		[msg26]="Only Nautilus, Nemo and Caja file managers are supported!"
		[msg27]="Failed to determine the desktop manager"
		[msg28]="Create Desktop Launch icon"
		[msg29]="Icons not restored"
		[msg30]="Failed to get"
		[msg31]="icon zoom"
		[msg32]="Undefined"
	)
}


get_languages ()
{
local reply='English'
if [ -s "$lang_file" ]; then
	reply=$(sed '/^\[/!d' "$lang_file" | sed '/.*\]$/!d' | sed 's/\[//;s/\]//' | sed '1i English\' | sort | uniq | tr '\n' ' ' )
fi
echo "$reply"
}



#arguments $1 = $language
set_language()
{
local reply
reply=$(zenity --title="$title_text" --hide-header --text="${lang[main7]}" --list --cancel-label="${lang[pb_return]}" \
	--ok-label="${lang[pb_select]}" --column="" "${lang_list[@]}")
case "$?" in
	0) ;;
	*) if [ -z "$1" ]; then reply="English"; else reply="$1"; fi;;
esac
echo "$reply" | awk -F'|' '{print $1}'
}


#    $1
# language
language_config()
{
set_lang_default
case "$1" in
	       '') language="English";;
	'English') language="English";;
		    *) if [ -s "$lang_file" ]; then read_lang_data "$1"; fi;;
esac
}


#    $1
# language
read_lang_data()
{
local line
local tmp
local start=0
while read -r line; do
	case "$start" in
		"1") case "$line" in
			     *=*) tmp="${line%=*}"; lang[$tmp]="${line#*=}";;
			 esac
			 if [ "${line:0:1}" == "[" ]; then start=2; fi;;
		"0") case "$line" in
				"[""$1""]") start=1;;
			 esac;;
	esac
done < "$lang_file"
}


start_dialog ()
{
local overlapped
local undo_entry=()
local disintangle_entry=()
if [ "$undo_enabled" -eq 0 ]; then undo_entry=("${undo_entry[@]}" "Undo Last Operation" "${lang[main8]}"); fi
overlapped=$(gio info "$desktop_path"/* | sed '/metadata::'"$my_desktop_manager"'-icon-position:/!d' | sort | uniq -d)
if [ -n "$overlapped" ]; then disintangle_entry=("${disintangle_entry[@]}" "Separate Overlapping Icons" "${lang[main9]}"); fi
zenity --list \
	--title="    $title_text" \
	--text "${lang[main7]}:" --ok-label="${lang[pb_select]}"\
	--cancel-label="${lang[pb_done]}" --width $((screen_width * 10 / 40)) --height $((screen_height * 10 / 30)) \
	--column="" --column="" --hide-column=1 --hide-header "Save current icon positions" "${lang[main1]}" \
	"Save icon positions to grid" "${lang[main2]}" "Restore icon positions" "${lang[main3]}" \
	"${undo_entry[@]}" "${disintangle_entry[@]}" \
	"Configuration" "${lang[main4]}" "System Info" "${lang[main10]}" "Help" "${lang[main5]}" "About" "${lang[main6]}"
}



#   $1          $2           $3          $4            $5        $6         $7
# $pos"      "$margin" "$grid_dim" "$old_grid_dim" "$dim_max" "icons_per" x_min
convert_grid ()
{
local old_pos="$1"
local new_pos
local margin="$2"
local old_grid_dim="$4"
local new_grid_dim="$3"
local grid_delta=$(($3 - $4))
local new_grid_min
local new_grid_max
local group # the column or row of the icon starting with 1 for first column or first row
    group=$((((old_pos - margin)/ old_grid_dim) + 1))
    if [ "$group" -gt "$6" ]; then group="$6"; fi
	new_pos=$((old_pos + ((group - 1) * grid_delta)))
	new_grid_min=$((margin + ((group - 1) * new_grid_dim)))
	new_grid_max=$((new_grid_min + new_grid_dim))
	if [ "$new_pos" -lt "$new_grid_min" ]; then new_pos="$new_grid_min"; fi
	if [ "$new_pos" -ge "$new_grid_max" ]; then new_pos=$((new_grid_max - 1)); fi
	echo "$new_pos"
	return 0 
}



# arguments $1 = $restore_file
# arguments $2 = current icon positions 
# restore icon positions from file
restore_op ()
{
	local line
	local icon_name
	local position
	local x_pos
	local y_pos
	local name
	local failure_list
	while read -r line;	do
		icon_name=$(echo "$line" | awk -F\' '{print $2}' | awk -F/ '{print $NF}')
		position=$(echo "$line" | awk -F\' '{print $3}')
		position=${position#*-icon-position }
		x_pos=${position%,*}
		y_pos=${position#*,}
		if ! ret=$(echo "$2" | grep -F "$icon_name|$x_pos|$y_pos"); then # icon has moved ... restore
			eval "$line" >/dev/null 2>&1
			case "$?" in
				0) # the move operation forces a desktop refresh
					name=$(echo "$line" | awk -F'/' '{print $NF}' | awk -F\' '{print $1}')
					mv "$desktop_path/$name" "/var/tmp/Desktop/"
					mv "/var/tmp/Desktop/$name" "$desktop_path/";;
				1) 	if [ -z "$failure_list" ]; then failure_list="$line"; else failure_list="$failure_list\\n$line"; fi;;
			esac
		fi
	done < "$1"
	if [ -n "$failure_list" ]; then echo "$failure_list"; return 1; else return 0; fi
}


read_ini ()
{
local line
while read -r line; do
	case "$line" in
		     language=*) language=${line#*=};;
		 screen_width=*) screen_width=${line#*=};;
		screen_height=*) screen_height=${line#*=};;
		    icon_zoom=*) icon_zoom=${line#*=};;
		  left_margin=*) left_margin=${line#*=};;
		   top_margin=*) top_margin=${line#*=};;
		   grid_width=*) grid_width=${line#*=};;
		  grid_height=*) grid_height=${line#*=};;
		icons_per_row=*) icons_per_row=${line#*=};;
	 icons_per_column=*) icons_per_column=${line#*=};;
	esac
done < "$ini_file"
}


write_ini ()
{
local new_ini
new_ini="[configuration]
language=$language
icons_per_row=$icons_per_row
icons_per_column=$icons_per_column
left_margin=$left_margin
top_margin=$top_margin
grid_width=$grid_width
grid_height=$grid_height
screen_width=$screen_width
screen_height=$screen_height
icon_zoom=$icon_zoom"
echo -e "$new_ini" > "$ini_file"
}


# dialog box to pick field to be edited in ini file
edit_ini_dialog()
{
local reply
local edit_field
local lang_entry=()
local icon_entry=()
while [ 0 -eq 0 ]; do
	if [ -s "$lang_file" ]; then lang_entry=("language" "${lang[config1]} = $language"); fi
	if [ ! -s "$desktop_file" ]; then icon_entry=("dtop_icon" "${lang[msg28]}"); fi
	reply=$(zenity --list --title="$title_text" --text="${lang[config8]}:" \
	--width $((screen_width * 10 / 45)) --height $((screen_height * 10 / 30)) \
	--ok-label="${lang[pb_edit]}" --cancel-label="${lang[pb_return]}" --column="" --column="" --hide-header --hide-column=1 \
	--print-column=1 \
	"${lang_entry[@]}" \
	"icons_per_row" "${lang[config2]} = $icons_per_row" "icons_per_column" "${lang[config3]} = $icons_per_column" \
	"left_margin" "${lang[config4]} = $left_margin" "top_margin" "${lang[config5]} = $top_margin" \
	"grid_width" "${lang[config6]} = $grid_width" "grid_height" "${lang[config7]} = $grid_height" \
	"${icon_entry[@]}") || break

	edit_field=$(echo "$reply" | awk -F'|' '{print $1}')
	if [ -z "$edit_field" ]; then
		zenity --warning --text="${lang[msg24]}"
	else
		edit_field_dialog "$edit_field" || break
	fi
done
}

#                $1
# argument "$edit_field"
edit_field_dialog()
{
local original_val
local new_val
local etext
local ret
case "$1" in
		 'language') original_val="language";;
	'icons_per_row') etext="${lang[config2]}"; original_val=$icons_per_row;;
 'icons_per_column') etext="${lang[config3]}"; original_val=$icons_per_column;;
	  'left_margin') etext="${lang[config4]}"; original_val=$left_margin;;
	   'top_margin') etext="${lang[config5]}"; original_val=$top_margin;;
	   'grid_width') etext="${lang[config6]}"; original_val=$grid_width;;
	  'grid_height') etext="${lang[config7]}"; original_val=$grid_height;;
esac
case "$1" in
  'language') ret=$(set_language "$language")
			  [ "$ret" != "$language" ] || return 0
			  language="$ret"
			  sed -i "/language=/s/^.*/language=$ret/" "$ini_file"
			  language_config "$language";;
 'dtop_icon') create_desktop_icon; return 1;;
		   *) new_val=$(zenity --entry --title="$title_text" --ok-label="${lang[pb_save]}" --cancel-label="${lang[pb_cancel]}" \
			  --text="${lang[msg4]}\\n$etext:" --entry-text="$original_val") || return 0
			  ret=$(verify_limits "$1" "$new_val" "$etext") || return 0
			  if [ "$new_val" -ne "$original_val" ]; then
				  (($1=new_val))  #sets the variable defined by $1 to the new value
				  case "$1" in
					  'icons_per_row') grid_width=$(((x_max - left_margin - x_min - x_min) / (icons_per_row)));;
				   'icons_per_column') grid_height=$(((y_max - top_margin) / (icons_per_column)));;
				  esac
				  original_ini=$(cat "$ini_file")
				  update_icon_positions 'update' "$1" "original_val"
			  fi;;
esac
}


# arguments: $edit_field $new_val $etext
verify_limits()
{
[ -n "$2" ] || { zenity --warning --text="$3\\n\\n${lang[msg14]}"; return 1; } #checks for no value
[ "$2" -eq "$2" ] 2>/dev/null || { zenity --warning --text="$3\\n\\n${lang[msg6]}"; return 1; } #checks if the value is an integer
[ "$2" -ge 0 ] || { zenity --warning --text="$3\\n\\n${lang[msg5]}"; return 1; } # must not be negative
	case "$1" in
		    grid*) [ "$2" -gt 50 ] || { zenity --warning --text="${lang[msg21]}!"; return 1; };;
	icons_per_row) [ "$2" -gt 6 ] || { zenity --warning --text="${lang[config2]}: $new_val\\n\\n${lang[msg19]}!"; return 1; }
				   [ "$2" -lt 25 ] || { zenity --warning --text="${lang[config2]}: $new_val\\n\\n${lang[msg20]}!"; return 1; };;
 icons_per_column) [ "$2" -gt 4 ] || { zenity --warning --text="${lang[config3]}: $new_val\\n\\n${lang[msg19]}!"; return 1; }
				   [ "$2" -lt 15 ] || { zenity --warning --text="${lang[config3]}: $new_val\\n\\n${lang[msg20]}!"; return 1; };;
	     		*) return 0;;
	esac
return 0
}


#                $1       $2        $3
# arguments   command   item     value  
update_icon_positions ()
{
local msg
local original_pos
local original_ini
local new_pos
local failure_list
local file_to_restore=$restore_file
original_pos=$(read_icon_positions)
original_ini=$(cat "$ini_file")
case $1 in
	  'restore') file_to_restore=$restore_file
				 echo "$restore_ini" > "$ini_file"; read_ini
				 undo_ini="$original_ini"; undo_enabled=0
				 msg="${lang[msg2]}";;
	     'undo') file_to_restore="$undo_file"
				 echo "$undo_ini" > "$ini_file"; read_ini
				 undo_ini="$original_ini"
				 msg="${lang[msg3]}";;
	'move2grid') new_pos=$(convert_data "$original_pos" 'to_grid')
				 create_restore_file "$new_pos" "$restore_file"; msg="${lang[msg17]}"
				 undo_ini="$original_ini"; undo_enabled=0;;
	   'update') new_pos=$(convert_data "$original_pos" "$2" "$3")
				 create_restore_file "$new_pos" "$restore_file"; msg="${lang[msg7]}"
				 undo_ini=$(cat "$ini_file"); undo_enabled=0
				 write_ini;;
	 'separate') new_pos=$(convert_data "$original_pos" 'separate')
				 create_restore_file "$new_pos" "$restore_file"; msg="${lang[msg23]}"
				 undo_ini=$(cat "$ini_file"); undo_enabled=0;;			 
esac
failure_list=$(restore_op "$file_to_restore" "$original_pos") || failure_warning "$failure_list" "$original_pos"
notify-send --hint=int:transient:1 -a Icons "$msg"
create_restore_file "$original_pos" "$undo_file"
undo_enabled=0
}


# $1 = $failure_list  $2 = $original_pos
failure_warning ()
{
create_restore_file "$2" "$restore_file"
zenity --question --ok-label="${lang[pb_view]}" --cancel-label="${lang[pb_return]}" \
	--width $((screen_width * 10 / 35)) --text="${lang[msg25]}" || return 0

echo -e "$1" |	awk -F\' '{print $2}' | awk -F'/' '{print $NF}' \
	| zenity --text-info --cancel-label="${lang[pb_return]}" --title="${lang[msg29]}"
}

get_mint_version ()
{
local ret
ret=$(echo "$1" | awk -F 'Linux Mint ' '{print $2}' | sed 's/[^0-9]*//g')
if [ "$ret" -ge 182 ]; then ret='Mint 18.2 and after'; else ret='Mint prior to 18.2'; fi
echo "$ret"
return 0
}


# $1 = my_distro_long
get_distro_version ()
{
local distro
case "$1" in
        *'Ubuntu'*) distro='Ubuntu';;
    *'Linux Mint'*) distro=$(get_mint_version "$1");;
                 *) distro='other';;
esac
echo "$distro"
return 0
}


get_desktop_manager ()
{
local d_man
local cnt
d_man=$(gio info "$desktop_path"/* | grep -E 'icon-position:' | awk -F':' '{print $3}' | sed 's/\-icon-position//' | sort | uniq)
[ -n "$d_man" ] || { zenity --warning --no-wrap --text="${lang[msg27]}\\n\\n ... ${lang[msg18]}"; exit 1; }
cnt=$(echo "$d_man" | wc -l)
# if more than one desktop manager found, then use the distro to determine
if [ "$cnt" -gt 1 ]; then
	case "$my_distro" in
		*'Ubuntu'*) d_man=$(xdg-mime query default inode/directory);;
		  *'Mint'*)	case "$DESKTOP_SESSION" in
						'cinnamon') d_man='nemo';;
						    'mate') d_man='caja';;
							     *) d_man='unknown';;
					esac;;
				 *) d_man=$(xdg-mime query default inode/directory);;
	esac
fi
case "$d_man" in
	 'nautilus'|'nemo'|'caja') echo "$d_man"; return 0;;
	  					    *) zenity --warning --no-wrap --text="${lang[msg26]}"; exit 1;;
esac
}


# arguments $my_distro $my_desktop_manager
get_zoom ()
{
local i_zoom
case "$2" in
 'nautilus') i_zoom=$(gsettings get org.gnome.nautilus.icon-view default-zoom-level) \
		      || { zenity --warning --no-wrap \
			 --text="${lang[msg30]} Nautilus Icon Zoom\\n\\n ...${lang[msg18]}"; return 1; };;
	 'nemo') i_zoom=$(gsettings get org.nemo.icon-view default-zoom-level) \
		      || { zenity --warning --no-wrap \
			 --text="${lang[msg30]} Nemo  Icon Zoom\\n\\n ...${lang[msg18]}"; return 1; };;
     'caja') i_zoom=$(gsettings get org.mate.caja.icon-view default-zoom-level) \
		      || { zenity --warning --no-wrap \
			 --text="${lang[msg30]} Caja  Icon Zoom\\n\\n ...${lang[msg18]}"; return 1; };;
	   	  *) return 1;;
esac
if [ "$1" == 'Mint 18.2 and after' ] && [ "$DESKTOP_SESSION" == 'cinnamon' ]; then i_zoom='standard'; fi
case "$i_zoom" in
	*"smallest"*) echo 33;;
	*"smaller"*) echo 50;;
	*"small"*) echo 66;;
	*"standard"*) echo 100;;
	*"larger"*) echo 200;;
	*"largest"*) echo 400;;
	*"large"*) echo 150;;
	*) zenity --warning --no-wrap --text="${lang[msg32]} ${lang[msg31]}: $i_zoom\\n\\n ...${lang[msg18]}"; return 1;;
esac
return 0
}


#                $1                    $2     
#arguments $screen_width or height $icon_zoom 
get_max ()
{
local max_val
max_val=$((($1 * 100) / $2))
echo "$max_val"
}


#User entry of 'icons_per_row' and 'icons_per_column'. Then calculate grid_width and grid_height  
set_icon_spacing ()
{
local ret
local new_val_per_row
local new_val_per_col
local new_val_per_row_ok
local new_val_per_col_ok
while [ 0 -eq 0 ]; do 
	ret=$(zenity --forms --ok-label="${lang[pb_save]}" --cancel-label="${lang[pb_cancel]}" --title "${lang[msg15]}" \
	--text "${lang[msg16]}" --add-entry="${lang[config2]}" --add-entry "${lang[config3]}")
	if [ "$?" -eq 0 ]; then
		new_val_per_row=$(awk -F'|' '{print $1}' <<<$ret)
		verify_limits 'icons_per_row' "$new_val_per_row" "${lang[config2]}"
		new_val_per_row_ok="$?"
		new_val_per_col=$(awk -F'|' '{print $2}' <<<$ret)
		verify_limits 'icons_per_column' "$new_val_per_col" "${lang[config3]}"
		new_val_per_col_ok="$?"
		if [ $new_val_per_row_ok -eq 0 ] && [ $new_val_per_col_ok -eq 0 ]; then
			icons_per_row="$new_val_per_row"
			icons_per_column="$new_val_per_col"
			break
		fi
	else
		zenity --warning --text="${lang[msg14]}\\n\\n ...${lang[msg18]}"
		return 1
	fi
	done
return 0
}


# arguments  $1 = icon_data
#Sets margin based on icon position if possible otherwise calculates based on grid size
set_margins ()
{
local line
local icon_name
local x_pos
local y_pos
local r_min
local this_r_min
local junk
local grid_w_max=$((x_max / icons_per_row))
local grid_h_max=$((y_max / icons_per_column))
local quad_1=1
local tmp_x=$x_max
local tmp_y=$y_max
IFS='|'
while read -r icon_name x_pos y_pos junk; do
	case "$quad_1" in
		0) this_r_min=$(((x_pos * x_pos) + (y_pos * y_pos)))	
		   if [ "$this_r_min" -lt "$r_min" ]; then
			   r_min="$this_r_min"
			   if [ "$x_pos" -le "$x_min" ]; then left_margin=0; else left_margin=$((x_pos - x_min)); fi
			   top_margin="$y_pos"	
			fi;;
		*)  if [ "$x_pos" -le "$grid_w_max" ] && [ "$y_pos" -le "$grid_h_max" ]; then
				quad_1=0
				r_min=$(((x_pos * x_pos) + (y_pos * y_pos)))
			    if [ "$x_pos" -le "$x_min" ]; then left_margin=0; else left_margin=$((x_pos - x_min)); fi
			    top_margin="$y_pos"
			else
				if [ "$x_pos" -le "$tmp_x" ]; then tmp_x="$x_pos"; fi 
				if [ "$y_pos" -le "$tmp_y" ]; then tmp_y="$y_pos"; fi 
			fi;;
	esac
done <<< "$1"
unset IFS
	case "$quad_1" in
		0)	grid_width=$((((x_max * 2) - (left_margin * 2)) / ((icons_per_row * 2 ) + 0 )))
			grid_height=$((((y_max * 2) - (top_margin * 2))/ ((icons_per_column *2) + 0)));;
		1)	if [ "$tmp_x" -le "$grid_w_max" ]; then
				if [ "$tmp_x" -le "$x_min" ]; then left_margin=0; else left_margin=$((tmp_x - x_min)); fi
				grid_width=$((((x_max * 2) - (left_margin * 2)) / ((icons_per_row * 2 ) + 0 )))
			else # autoset left margin
 				grid_width=$((((x_max * 2) - (x_min * 4)) / ((icons_per_row * 2 ) + 1 )))
				left_margin=$((grid_width / 2))
			fi
		  	if [ "$tmp_y" -le "$grid_h_max" ]; then
				top_margin="$tmp_y"
				grid_height=$((((y_max * 2) - (top_margin * 2))/ ((icons_per_column *2) + 0)))
			else # autoset top margin
				grid_height=$(((y_max * 2) / ((icons_per_column *2) + 1)))
				top_margin=$((grid_height / 2))
			fi;;
	esac
}


# arguments
# $1 = icon_data
# $2 change type ='to_grid'|'left_margin'|'top_margin'|'grid_width'|'grid_height'|'separate'
# $3 = amount of change|old_value
convert_data ()
{
local icon_name
local prefix_str
local x_pos
local y_pos
local col
local row
local prefix_str
local tmp=''
local old_pos=''
local cnt=0
IFS='|'
while read -r icon_name x_pos y_pos col row prefix_str; do
	case "$2" in
		'to_grid')	left_min=$((left_margin + x_min)) # x-axis icon canvas offset
					x_pos=$(convert_coordinates "$x_pos" "$left_min" "$grid_width" "$x_max")
					y_pos=$(convert_coordinates "$y_pos" "$top_margin" "$grid_height" "$y_max");;
	'left_margin')	x_pos=$((x_pos + left_margin - $3));;
	 'top_margin')	y_pos=$((y_pos + top_margin - $3));;
	 'grid_width')	x_pos=$(convert_grid "$x_pos" "$((x_min + left_margin))" "$grid_width" "$3" "$x_max" "$icons_per_row");;
	'grid_height')	y_pos=$(convert_grid "$y_pos" "$top_margin" "$grid_height" "$3" "$y_max" "$icons_per_column");;
	   'separate') 	if [ "$x_pos|$y_pos" == "$old_pos" ]; then cnt=$((cnt + 1)); else cnt=0; fi
					old_pos="$x_pos|$y_pos"
					if ret=$(echo -e "$tmp" | grep -F "$x_pos|$y_pos"); then
						x_pos=$((x_pos + (cnt * (grid_width / 4))))
						y_pos=$((y_pos + (cnt * (grid_height / 5))))
					fi;;
	esac
	x_pos=$(check_min_max "$x_pos" "$left_margin" "$grid_width" "$x_max" "$2")
	y_pos=$(check_min_max "$y_pos" "$top_margin" "$grid_height" "$y_max" "$2")
	tmp="$tmp\\n$icon_name|$x_pos|$y_pos|||$prefix_str"
done <<< "$1"
unset IFS
tmp=$(echo -e "$tmp" | sed '/^\s*$/d' | sort -t\| -k2g,2 -k3g,3) # sort by columns and then row
echo -e "$tmp"
}

#                $1       $2    $3   $4      $5
# arguments: position, margin, grid, max, command
check_min_max ()
{
local ret=$1
if [ "$ret" -lt "$2" ]; then ret="$2"; fi
if [ "$ret" -gt $(($4 - $3)) ]; then ret=$((((($4 - $2) / $3) * $3) + $2 )); fi
case "$5" in
    'to_grid') if [ "$ret" -gt $(($4 - ($3 / 2))) ]; then ret=$((ret - $3)); fi;;
            *) if [ "$ret" -gt $(($4 - ($3 / 2))) ]; then ret=$(($4 - ($3 / 2))); fi;;
esac
echo "$ret"
}


# arguments: position, margin, grid, max
# this routine converts an icon coordinates to the closest grid lines
convert_coordinates ()
{
local ret
	if [ "$1" -le "$2" ]; then
		ret=$2
	else
		ret=$((((($1-$2) / $3) * $3) +$2))
		if [ $((((($1-$2) % $3) * 2))) -gt "$3" ]; then ret=$((ret + $3)); fi
		if [ "$ret" -gt $(($4 - $3)) ]; then ret=$((((($4 - $2) / $3) * $3) + $2 )); fi
	fi
	echo "$ret"
}



### Program Start #########

language_config 'English'
lang_list=($(get_languages))

# Read .ini file if it exists
if [ -s "$ini_file" ]; then
	read_ini
	x_max=$(get_max "$screen_width" "$icon_zoom")
	y_max=$(get_max "$screen_height" "$icon_zoom")
else
	if [ -s "$lang_file" ]; then language=$(set_language ""); else language='English'; fi
fi
if [ ! "$language" == 'English' ]; then language_config "$language"; fi


#check if gvfs-info is installed
command -v gio info >/dev/null 2>&1 || { zenity --warning --no-wrap --text="\\ngvfs-info is required to obtain\\nicon positions but is not installed.\\n\\n ...${lang[msg18]}"; exit 1; }

# create tmp directory if it does not exist
if [ ! -d "/var/tmp/Desktop" ]; then mkdir /var/tmp/Desktop; fi

# get the necessary system info
my_distro_long=$(cat /etc/*-release 2>/dev/null | grep 'PRETTY_NAME' | awk -F'=' '{print $2}' \
	| sed 's/\"//g') || { zenity --warning --no-wrap --text="\\nDistro information not found! ...${lang[msg18]}"; exit 1; }
my_distro=$(get_distro_version "$my_distro_long") 
my_desktop_manager=$(get_desktop_manager "$my_distro")
available_screen=$(get_screen_data) || exit 0
current_screen_width=$(echo "$available_screen" | cut -d ',' -f3 | sed -e 's/^[ \t]*//')
current_screen_height=$(echo "$available_screen" | cut -d ',' -f4 | sed -e 's/^[ \t]*//')
current_zoom=$(get_zoom "$my_distro" "$my_desktop_manager") || exit 0

icon_data=$(read_icon_positions)

# if restore file does not exist then create it
[ -s "$restore_file" ] || create_restore_file "$icon_data" "$restore_file"

# if ini file missing, create it
if [ ! -s "$ini_file" ]; then
	screen_width=$current_screen_width
	screen_height=$current_screen_height
	icon_zoom=$current_zoom
	x_max=$(get_max "$screen_width" "$icon_zoom")
	y_max=$(get_max "$screen_height" "$icon_zoom")
	set_icon_spacing || exit 0
	set_margins "$icon_data" || exit 0
	write_ini
	create_icon="true"
fi

restore_ini=$(cat "$ini_file")

# checking for screen changes 
check_for_screen_changes

# on first run create desktop icon 
[ "$create_icon" == "true" ] && create_desktop_icon

while [ 0 -eq 0 ]; do
	reply="$(start_dialog)" || break
	if [ -z "$reply" ]; then zenity --warning --text="${lang[msg24]}"; fi
	reply=$(echo "$reply" | awk -F'|' '{print $1}')
	case "$reply" in
   "Save current icon positions") icon_data=$(read_icon_positions)
								  restore_ini=$(cat "$ini_file");
								  create_restore_file "$icon_data" "$restore_file"; icon_data=''
								  notify-send --hint=int:transient:1 -a Icons "${lang[msg1]}";;
   "Save icon positions to grid") update_icon_positions 'move2grid';; # exit 0
   		"Restore icon positions") update_icon_positions 'restore';; 
		   "Undo Last Operation") update_icon_positions 'undo';;
	"Separate Overlapping Icons") update_icon_positions 'separate';;
   				 "Configuration") read_ini; edit_ini_dialog;;
				   "System Info") display_sys_info;;
   						  "Help") display_help;;
   						 "About") about_this;;
	esac
done
exit 0

#done
#   Happy Desktop
#   Version 2.00
#   10OCT2017
#   drm200@free.fr
#
#   copyright © 2017 retiredbutstillhavingfun
#
#  This program is used to save/restore/align the Ubuntu and Mint Desktop icons
#  positions when Nautilus, Nemo, or Caja is managing the desktop.
#  This has been tested with
#     Ubuntu 14.04 with Nautilus
#     Ubuntu 16.04 with Nautilus
#     Mint 18.1 Cinnamon with Nemo
#     Mint 18.2 Cinnamon with Nemo
#     Mint 18.2 Mate with Caja
#	
#   Requirements (all are included with the default Ubuntu and Mint installations):
#     Nautilus, Nemo or Caja is your file manager
#     gvfs-info (which is used by Nautilus, Nemo & Caja to store icon positions)
#     bash, zenity, gsettings, xprop, sed, grep, awk, xdg-mime
#
#
#Purpose: This script provides a GUI interface for all actions:
#    ...Saves the current icon layout to file
#    ...Align your icon positions to a grid and save the new layout to file
#    ...Restore your icon layout using the previously saved file
#
##### Installation Instructions  ####
#
#1. Copy the three files:
#		Happy_Desktop.sh
#		Happy_Desktop.png
#		happy_desktop.lang (optional)
#
# 	to either your bin or nautilus scripts folder or subfolder with name of your choice:
#        (/home/YourUserName/bin) or
#        (/home/YourUserName/.local/share/nautilus/scripts) or
#        (/home/YourUserName/bin/anysubfolder) or
#        (/home/YourUserName/.local/share/nautilus/scripts/anysubfolder)
#
### Initial Setup ####
#
#1. During initial run of the script, you will be asked to enter the "icons per row" and icons per column" you want for your desktop. These two variables determines how the icon grid alignment function will work for the program.  For example, if you enter "10" for "icons per column", this means that program will calculate an icon row "height" that allows for 10 equally spaced rows for each column.  Similarly, the "icons per row" setting allows the program to calculate the icon column "width" for each icon in a row. So, prior to running the script, determine how many "icons per row" and "icons per column" you want.  If you decide later to change the setting, it can be accomplished throught the configuration menu.
#
#2. Right click on the desktop. Select "Desktop" and then deselect "Auto-arrange" and "Align to grid"
#
#3. Run the script. 
#    a). If you copied the "happy_desktop.lang" file, you will be asked to select your language.
#    b). Input the "icons per column" and "icons per row" values that you desire.
#    c). You will be given the option to create a desktop icon to launch Happy Desktop the first time you run the script. You can always delete the desktop icon later if you desire to run the script directly.  
#
#4. On the first run, two files will be created in the installation directory:
#
#      happy_desktop.ini   (where your preferences are saved)
#      happy_desktop_restore.dat   (used to restore icon positions)
#
#### Using the Program ####
#
#1. Use "Save Current Icon Positions" to save the current icon positions to file (happy_desktop_restore.dat)
#
#2. Use "Restore Icon Positions" to reposition icons on the desktop using the data from the "happy_desktop_restore.dat" file
#
#3. Use "Undo last operation" to "undo" the last restore operation.
#
#### Using the Grid Function ####
#
#1. Use "Save Icon Positions to Grid" to automatically move icons left/right/up/down to the nearest grid lines as defined by your initial "icons per row" and "icons per column" settings.  This will perfectly align icons in rows and columns.
#
#2. Use "Undo last operation" to "undo" the last "Save Icon Positions to Grid" operation.
#
#3. During initial "Save Icon Positions to Grid" it is normal that some adjacent icons may be moved to the same positions and then be overlapping.  Use "Disintangle Overlapping Icons" to automatically separate these icons.  Then move the icons to an open row or position of your liking and "Save Icon Positions to Grid" again.
#
#4. To "fine tune" the grid layout, go into "Configuration" and change the "Left Margin", "Top Margin", "Grid Width", and "Grid Height" to modify the layout to your preference.
#
#### Notes ####
#
#   Note: The "System Icons" (Computer, Home Folder, Trash, Network Servers, Mounted Volumes) can not be modified or controlled by "Happy Desktop".  However, by adjusting the margins and grid values, you can align the user desktop files/folders to the system icons (if you desire).
#
#   Note: The "Icons Per Row" and "Icons per column" values are only used to determine initial grid values.  After that, the margins and grid dimensions control the layout. Changing the "Icons Per Row" and "Icons per column" again will also change the grid dimensions (but not the margins).
#
#   Note: This program uses your screen resolution and the "default icon zoom" (under Nautilus\preferences) to determine the initial grid size.  Changing either the screen resolution or "default icon zoom" will require the repeat of the initial setup.
#
#   Note: This version of Happy Desktop no longer requires "xdotool" to position the icons.
#
### Language Translations ####
#
#   Happy Desktop supports a multilanguage interface by using the file "happy_desktop_lang.  To add support for your language, just add your translations to "happy_desktop_lang". Your new language will automatically appear as an option in the language configuration menu.  If you do not need multilanguage support, you can erase the "happy_desktop_lang" file.
#
#### Creating a desktop icon  ####
#
#1. The program will prompt you to create a desktop icon to launch the application on the first script run.  If you did not create a desktop icon on the first script run, you can delete the file "Happy_Desktop.ini" and then the next time you run the script it will prompt you again to create the desktop launch icon.
##### Change log ####
# Version 2.00 ... new release
# xdotool no longer required
# compatible with Ubuntu, Mint Cinnamon, Mint Mate
#
#gnu_text
#This program is free software; you can redistribute
#it and/or modify it under the terms of the GNU General
#Public License as published by the Free Software
#Foundation; either version 2 of the License, or
#(at your option) any later version.
#
#This program is distributed in the hope that it will be
#useful, but WITHOUT ANY WARRANTY; without even
#the implied warranty of MERCHANTABILITY or FITNESS
#FOR A PARTICULAR PURPOSE.  See the GNU General
#Public License for more details.

#You should have received a copy of the GNU General
#Public License along with this program; if not, write
#to:
#              Free Software Foundation, Inc.
#              51 Franklin St, Fifth Floor
#              Boston, MA  02110-1301 USA

