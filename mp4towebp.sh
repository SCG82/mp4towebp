#!/bin/bash

#************************************************
#                mp4towebp.sh                   *
#                  v2.0.0                       *
# developer: SCG82 (scg082+mp4towebp@gmail.com) *
#************************************************

USAGE_S="Usage: $0 -w width -h height -n [select every nth frame] -p preset -z [0-9] -m [0-6] -q [quality level: 0-100] -a [alpha-quality: 0-100] -f [filter level: 0-100, af] -l [1+ = # of times to repeat, 0 = infinite] -s [start time hh:mm:ss] -e [end time hh:mm:ss] FILE"
USAGE="Usage (arguments are optional): $0 -w [output width] -h [output height] -n [select every nth frame] -p [preset: default,photo,picture,drawing,icon,text] -z [lossless preset: (0=fast, 9=slow)] -m [compression method: (0=fast, 6=slow)] -q [quality level: 0-100 (90)] -a [alpha-quality: 0-100 (100)] -f [filter level: 0-100, af (af)] -l [1+ = # of times to repeat, 0 = infinite] -s [start time hh:mm:ss] -e [end time hh:mm:ss] FILE"
VERSION="2.0.0"

# if filename not supplied display usage message and die
[ $# -eq 0 ] && { echo "$USAGE_S"; exit 1; }

_file=""
hsize=-1
vsize=-1
fps=30
n=1
preset="default"
lossless=0
z=6
m=5
q=90
aq=100
sns=80
f=30
# f=af
#use_af=0
use_af=1
sharp=3
start="0:0:0"
endtime=""
has_start=0
has_end=0
full=1
loop=0
aspect_changed=0

pix_fmt="yuv420p"

in_color_range="tv"

in_width=1920
in_height=1080

out_height=-1

while getopts ":w:h:n:p:z:m:q:a:f:l:s:e:vH" optname
	do
		case "$optname" in
			"v")
				echo "Version $VERSION"
				exit 0;
			;;
			"w")
				if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 1 ]; then
					hsize=$OPTARG
				else
					echo "invalid width: \"$OPTARG\"" && exit 1
				fi
			;;
			"h")
				if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 1 ]; then
					vsize=$OPTARG
				else
					echo "invalid height: \"$OPTARG\"" && exit 1
				fi
			;;
			"n")
				if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 1 ]; then
					n=$OPTARG
				else
					echo "invalid entry for n: \"$OPTARG\"" && exit 1
				fi
			;;
			"p")
				if [[ "$OPTARG" =~ [a-zA-Z0-9_]+$ ]]; then
					echo "preset: $OPTARG"
					preset=$OPTARG
				else
					echo "invalid preset: \"$OPTARG\"" && exit 1
				fi
			;;
			"z")
				if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 0 ] && [ "$OPTARG" -le 9 ]; then
					z=$OPTARG
					lossless=1
				else
					echo "invalid entry for z: \"$OPTARG\"" && exit 1
				fi
			;;
			"m")
				if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 0 ] && [ "$OPTARG" -le 6 ]; then
					m=$OPTARG
				else
					echo "invalid entry for m: \"$OPTARG\"" && exit 1
				fi
			;;
			"q")
				if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 0 ] && [ "$OPTARG" -le 100 ]; then
					q=$OPTARG
				else
					echo "invalid entry for q: \"$OPTARG\"" && exit 1
				fi
			;;
			"a")
				if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -ge 0 ] && [ "$OPTARG" -le 100 ]; then
					a=$OPTARG
				else
					echo "invalid entry for a: \"$OPTARG\"" && exit 1
				fi
			;;
			"f")
				if [[ "$OPTARG" =~ ^[0-9]+$ ]]; then
					f=$OPTARG
					use_af=0
				elif [[ "$OPTARG" =~ ^af$ ]]; then
					f=$OPTARG
					use_af=1
				else
					echo "invalid entry for filter strength: \"$OPTARG\"" && exit 1
				fi
			;;
			"l")
				if [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -eq 0 ]; then
					loop=0
				elif [[ "$OPTARG" =~ ^[0-9]+$ ]] && [ "$OPTARG" -gt 0 ]; then
					loop=$OPTARG
				else
					echo "invalid entry for looping: \"$OPTARG\"" && exit 1
				fi
			;;
			"s")
				if [[ "$OPTARG" =~ ^[0-9:.]+$ ]]; then
					echo "start time: $OPTARG"
					start=$OPTARG
					has_start=1
				else
					echo "invalid start time: \"$OPTARG\"" && exit 1
				fi
			;;
			"e")
				if [[ "$OPTARG" =~ ^[0-9:.]+$ ]]; then
					echo "end time: $OPTARG"
					endtime=$OPTARG
					has_end=1
				else
					echo "invalid end time: \"$OPTARG\"" && exit 1
				fi
			;;
			"H")
				echo "$USAGE"
				exit 0;
			;;
			"?")
				echo "Unknown option $OPTARG"
				exit -1;
			;;
			":")
				echo "No argument value for option $OPTARG"
				exit -1;
			;;
			*)
				echo "Unknown error while processing options"
				exit -1;
			;;
		esac
	done

shift $(($OPTIND - 1))

_file=$1

# if file not found, display an error and die
[ ! -f "$_file" ] && { echo "$0: $_file file not found."; exit 2; }

file_inc_ext="$(basename "$_file")"
file_no_ext="${file_inc_ext%.*}"
in_dir="$(echo "$(cd "$(dirname "$1")" && pwd -P)")"

#fps=$(ffmpeg -i "$_file" 2>&1 | sed -n "s/.*, \([^k]*\) tbr.*/\1/p")

fps_tbr=$(ffprobe -v error -show_entries stream=r_frame_rate -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$_file")

fps_num=${fps_tbr%%/*}
fps_den=${fps_tbr##*/}

fps=$(echo "scale=4; $fps_num / $fps_den" | bc)

out_fps=$(echo "scale=4; $fps / $n" | bc)

in_width=$(ffprobe -v error -show_entries stream=width -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$_file")
in_height=$(ffprobe -v error -show_entries stream=height -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$_file")

in_sar_raw=$(ffprobe -v error -show_entries stream=sample_aspect_ratio -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$_file")

in_sar_num=${in_sar_raw%%:*}
in_sar_den=${in_sar_raw##*:}

in_sar=$(echo "scale=4; $in_sar_num / $in_sar_den" | bc)

if [ $hsize -ne -1 ]; then
	out_width=$hsize
else
	out_width=$in_width
fi

out_height_calc="($out_width*$in_height*$in_sar_den)/($in_width*$in_sar_num)"
out_height_bc=$(echo "scale=2; ($out_height_calc+0.5)/1" | bc)
out_height=$(echo "scale=0; $out_height_bc/1" | bc)

if [ $vsize -ne -1 ]; then
	if [ $out_height -ne $vsize ]; then
		aspect_changed=1
	fi
	out_height=$vsize
fi

if [ $loop -eq 0 ]; then
	echo "loop:    infinite"
else
	echo "loop:    $loop"
fi

#duration=$((n*1000/fps))
duration=$(echo "scale=0; $n * 1000 / $fps" | bc)

# color_range_probe=$(ffprobe -v error -show_entries stream=color_range -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$_file")
# color_space_probe=$(ffprobe -v error -show_entries stream=color space -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$_file")
# color_primaries_probe=$(ffprobe -v error -show_entries stream=color_primaries -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$_file")

pix_fmt_probe=$(ffprobe -v error -show_entries stream=pix_fmt -of default=noprint_wrappers=1:nokey=1 -select_streams v:0 "$_file")

if [[ "$pix_fmt_probe" =~ ^unknown$ ]]; then
	pix_fmt="yuv420p"
	echo "(note: input pixel format unknown)"
elif [[ "$pix_fmt_probe" =~ ^[y|u][u|y]y?v[j|y|y]?y?[0-9b-p]+$ ]]; then
	pix_fmt="yuv420p"
	is_yuv=1
	use_rgb=0
	has_alpha=0
elif [[ "$pix_fmt_probe" =~ ^yuva[0-9b-p]+ ]] || [[ "$pix_fmt_probe" =~ ^ayuv[0-9b-p]+ ]]; then
	pix_fmt="yuva420p"
	is_yuv=1
	use_rgb=0
	has_alpha=1
elif [[ "$pix_fmt_probe" =~ ^[a|r|g|b][a|r|g|b][a|r|g|b][a|r|g|b][a-z0-9]*$ ]]; then
	pix_fmt="rgba"
	is_yuv=0
	use_rgb=1
	has_alpha=1
else
	pix_fmt="rgb24"
	is_yuv=0
	use_rgb=1
	has_alpha=0
fi

echo "select 1 of every $n frames"
echo "in  fps: $fps"
echo "out fps: $out_fps"
if [ $lossless -eq 1 ]; then
	echo "lossless compression"
	echo "z = $z"
else
	echo "lossy compression"
	echo "m = $m"
fi
echo "q = $q"
echo "a = $aq (alpha quality)"
echo "filter strength:  $f"
echo "filter sharpness: $sharp"

echo "input  pixel format: $pix_fmt_probe"
echo "output pixel format: $pix_fmt"

echo "input  size: $in_width x $in_height"
echo "output size: $out_width x $out_height"

if [ $aspect_changed -eq 1 ]; then
	echo "(note: aspect ratio will be changed from original)"
fi

TEMPDIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'mp4towebp')

trap 'rm -rf "$TEMPDIR" >/dev/null 2>&1' 0
trap "exit 2" 1 2 3 13 15

mkdir "${TEMPDIR}/frames"

FRAMESDIR="${TEMPDIR}/frames"

# filter="select=not(mod(n\,${n})),scale=${out_width}:${out_height}"
filter="select=not(mod(n\,${n})),scale=${out_width}:${out_height}"
sws_flags="lanczos+accurate_rnd+full_chroma_int+full_chroma_inp+bitexact"

echo "extracting frames..."
if [ $lossless -eq 0 ]; then
	if [ $is_yuv -eq 1 ]; then
		if [ $has_end -eq 1 ]; then
			ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -to $endtime -f image2 -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "${FRAMESDIR}"/frame%05d.raw
		elif [ $has_start -eq 1 ] && [ $has_end -eq 0 ]; then
			ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -f image2 -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "${FRAMESDIR}"/frame%05d.raw
		else
			ffmpeg -hide_banner -loglevel panic -i "$_file" -f image2 -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "$FRAMESDIR"/frame%05d.raw
		fi
	else
		if [ $has_alpha -eq 1 ]; then
			if [ $has_end -eq 1 ]; then
				ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -to $endtime -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "${FRAMESDIR}"/frame%05d.png
			elif [ $has_start -eq 1 ] && [ $has_end -eq 0 ]; then
				ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "${FRAMESDIR}"/frame%05d.png
			else
				ffmpeg -hide_banner -loglevel panic -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "$FRAMESDIR"/frame%05d.png
			fi
		else
			if [ $has_end -eq 1 ]; then
				ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -to $endtime -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "${FRAMESDIR}"/frame%05d.png
			elif [ $has_start -eq 1 ] && [ $has_end -eq 0 ]; then
				ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "${FRAMESDIR}"/frame%05d.png
			else
				ffmpeg -hide_banner -loglevel panic -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "$FRAMESDIR"/frame%05d.png
			fi
		fi
	fi
else
	if [ $is_yuv -eq 0 ]; then
		if [ $has_end -eq 1 ]; then
			ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -to $endtime -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "${FRAMESDIR}"/frame%05d.png
		elif [ $has_start -eq 1 ] && [ $has_end -eq 0 ]; then
			ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "${FRAMESDIR}"/frame%05d.png
		else
			ffmpeg -hide_banner -loglevel panic -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt $pix_fmt "$FRAMESDIR"/frame%05d.png
		fi
	else
		if [ $has_alpha -eq 1 ]; then
			if [ $has_end -eq 1 ]; then
				ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -to $endtime -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt rgba "${FRAMESDIR}"/frame%05d.png
			elif [ $has_start -eq 1 ] && [ $has_end -eq 0 ]; then
				ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt rgba "${FRAMESDIR}"/frame%05d.png
			else
				ffmpeg -hide_banner -loglevel panic -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt rgba "$FRAMESDIR"/frame%05d.png
			fi
		else
			if [ $has_end -eq 1 ]; then
				ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -to $endtime -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt rgb24 "${FRAMESDIR}"/frame%05d.png
			elif [ $has_start -eq 1 ] && [ $has_end -eq 0 ]; then
				ffmpeg -hide_banner -loglevel panic -ss $start -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt rgb24 "${FRAMESDIR}"/frame%05d.png
			else
				ffmpeg -hide_banner -loglevel panic -i "$_file" -vf "$filter" -sws_flags "$sws_flags" -vsync vfr -pix_fmt rgb24 "$FRAMESDIR"/frame%05d.png
			fi
		fi
	fi
fi

cd "$FRAMESDIR" || exit

mkdir webp

WEBPDIR="${FRAMESDIR}/webp"

echo "building animated webP file..."

if [ $lossless -eq 0 ]; then
	if [ $use_af -eq 1 ]; then
		if [ $is_yuv -eq 1 ]; then
			for frame in *.raw; do cwebp -mt -preset $preset -m $m -q $q -alpha_q $aq -sns $sns -af -sharpness $sharp -alpha_filter best -quiet -s $out_width $out_height "$frame" -o "${WEBPDIR}/${frame%.*}.webp"; done
		elif [ $has_alpha -eq 1 ]; then
			for frame in *.png; do cwebp -mt -preset $preset -m $m -q $q -alpha_q $aq -sns $sns -af -sharpness $sharp -sharp_yuv -alpha_filter best -quiet "$frame" -o "${WEBPDIR}/${frame%.*}.webp"; done
		else
			for frame in *.png; do cwebp -mt -preset $preset -m $m -q $q -sns $sns -af -sharpness $sharp -sharp_yuv -alpha_filter best -quiet "$frame" -o "${WEBPDIR}/${frame%.*}.webp"; done
		fi
	else
		if [ $is_yuv -eq 1 ]; then
			for frame in *.raw; do cwebp -mt -preset $preset -m $m -q $q -alpha_q $aq -sns $sns -f $f -sharpness $sharp -alpha_filter best -quiet -s $out_width $out_height "$frame" -o "${WEBPDIR}/${frame%.*}.webp"; done
		elif [ $has_alpha -eq 1 ]; then
			for frame in *.png; do cwebp -mt -preset $preset -m $m -q $q -alpha_q $aq -sns $sns -f $f -sharpness $sharp -sharp_yuv -alpha_filter best -quiet "$frame" -o "${WEBPDIR}/${frame%.*}.webp"; done
		else
			for frame in *.png; do cwebp -mt -preset $preset -m $m -q $q -sns $sns -f $f -sharpness $sharp -sharp_yuv -alpha_filter best -quiet "$frame" -o "${WEBPDIR}/${frame%.*}.webp"; done
		fi
	fi
else
	if [ $is_yuv -eq 1 ]; then
		for frame in *.png; do cwebp -mt -preset $preset -lossless -z $z -q $q -alpha_q $aq -sns $sns -f $f -sharpness $sharp -alpha_filter best -quiet "$frame" -o "${WEBPDIR}/${frame%.*}.webp"; done
	elif [ $has_alpha -eq 1 ]; then
		for frame in *.png; do cwebp -mt -preset $preset -lossless -z $z -q $q -alpha_q $aq -sns $sns -f $f -sharpness $sharp -alpha_filter best -quiet "$frame" -o "${WEBPDIR}/${frame%.*}.webp"; done
	else
		for frame in *.png; do cwebp -mt -preset $preset -lossless -z $z -q $q -noalpha -sns $sns -f $f -sharpness $sharp -alpha_filter best -quiet "$frame" -o "${WEBPDIR}/${frame%.*}.webp"; done
	fi
fi

if [ $has_alpha -eq 0 ]; then
	for webpFile in "${WEBPDIR}"/*; do echo -n "-frame $webpFile +$duration " >> output.txt; done
else
	for webpFile in "${WEBPDIR}"/*; do echo -n "-frame $webpFile +$duration+0+0+1 " >> output.txt; done
fi

webpmux `cat output.txt` -loop $loop -o "${in_dir}"/"${file_no_ext}".webp

exit
