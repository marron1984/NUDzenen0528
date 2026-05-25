#!/bin/bash
set -e
cd "$(dirname "$0")/.."

W=1080
H=1350
DUR=3.5
INFO_DUR=6.0
FADE=0.5
FPS=30
FRAMES=$(awk -v d=$DUR -v f=$FPS 'BEGIN{print int(d*f)}')
INFO_FRAMES=$(awk -v d=$INFO_DUR -v f=$FPS 'BEGIN{print int(d*f)}')
FONT="/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc"
FONT_REG="/usr/share/fonts/opentype/noto/NotoSerifCJK-Regular.ttc"

# Position presets (x, y) for main text. Values chosen per scene to avoid busy areas.
# scene def: image | text_main | text_sub | pos
# pos values: TL, TC, TR, ML, MC, MR, BL, BC, BR
SCENES=(
  "DSC00686.jpg|大切な、その一席に。|—お忍びの接待に—|ML"
  "DSC00734.jpg|完全個室、ご用意。|ご接待・ご顔合わせに|TC"
  "DSC00736.jpg|落ち着いた半個室。|大切な商談にも|TR"
  "DSC00732.jpg|暖簾で仕切るテーブル席。|少人数のご会食に|BL"
  "DSC00738.jpg|寛ぎのカウンター。|お一人様・少人数にも|TL"
  "DSC00718修.jpg|心を込めた、おもてなしの一献。||TC"
  "DSC00723修.jpg|ひととき、ゆっくりと。||TR"
  "コース_空五倍子色コース0019.jpg|季節の会席とともに。|—四季の彩りを一皿に—|TC"
  "DSC00676.jpg|ご来店、お待ちしております。||BL"
)

# Resolve position to drawtext x:y expression
pos_xy() {
  case "$1" in
    TL) echo "x=80:y=120" ;;
    TC) echo "x=(w-text_w)/2:y=120" ;;
    TR) echo "x=w-text_w-80:y=120" ;;
    ML) echo "x=80:y=(h-text_h)/2" ;;
    MC) echo "x=(w-text_w)/2:y=(h-text_h)/2" ;;
    MR) echo "x=w-text_w-80:y=(h-text_h)/2" ;;
    BL) echo "x=80:y=h-text_h-160" ;;
    BC) echo "x=(w-text_w)/2:y=h-text_h-160" ;;
    BR) echo "x=w-text_w-80:y=h-text_h-160" ;;
  esac
}
pos_xy_sub() {
  case "$1" in
    TL) echo "x=80:y=205" ;;
    TC) echo "x=(w-text_w)/2:y=205" ;;
    TR) echo "x=w-text_w-80:y=205" ;;
    ML) echo "x=80:y=(h/2)+50" ;;
    MC) echo "x=(w-text_w)/2:y=(h/2)+50" ;;
    MR) echo "x=w-text_w-80:y=(h/2)+50" ;;
    BL) echo "x=80:y=h-text_h-100" ;;
    BC) echo "x=(w-text_w)/2:y=h-text_h-100" ;;
    BR) echo "x=w-text_w-80:y=h-text_h-100" ;;
  esac
}

# Strong shadow + thick black border for legibility without backdrop
TXT_STYLE="fontcolor=white:shadowcolor=black@0.9:shadowx=3:shadowy=3:borderw=4:bordercolor=black@0.7"
SUB_STYLE="fontcolor=white:shadowcolor=black@0.9:shadowx=2:shadowy=2:borderw=3:bordercolor=black@0.7"

rm -rf video_work/clips
mkdir -p video_work/clips

i=0
for scene in "${SCENES[@]}"; do
  IFS='|' read -r img main sub pos <<< "$scene"
  out=$(printf "video_work/clips/clip_%02d.mp4" $i)
  echo "=== Building $out from $img (pos=$pos) ==="

  XY_MAIN=$(pos_xy "$pos")
  XY_SUB=$(pos_xy_sub "$pos")

  TEXT_FILTER=""
  if [ -n "$main" ]; then
    TEXT_FILTER=",drawtext=fontfile='$FONT':text='$main':fontsize=58:${XY_MAIN}:${TXT_STYLE}"
  fi
  if [ -n "$sub" ]; then
    TEXT_FILTER="$TEXT_FILTER,drawtext=fontfile='$FONT_REG':text='$sub':fontsize=34:${XY_SUB}:${SUB_STYLE}"
  fi

  ffmpeg -y -loglevel error \
    -i "$img" \
    -filter_complex "
      [0:v]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},format=yuv420p,
        zoompan=z='min(zoom+0.0015,1.10)':d=${FRAMES}:s=${W}x${H}:fps=${FPS}
        ${TEXT_FILTER},
        fade=t=in:st=0:d=${FADE},fade=t=out:st=$(awk -v d=$DUR -v f=$FADE 'BEGIN{print d-f}'):d=${FADE}
    " \
    -t ${DUR} -c:v libx264 -pix_fmt yuv420p -r ${FPS} "$out"
  i=$((i+1))
done

# === Info card (店舗情報) ===
INFO_IMG="DSC00741.jpg"
INFO_OUT=$(printf "video_work/clips/clip_%02d.mp4" $i)
echo "=== Building $INFO_OUT (store info card) ==="

# Write each line to a text file (avoids ffmpeg colon-escaping issues)
TXTDIR=video_work/txt
rm -rf "$TXTDIR" && mkdir -p "$TXTDIR"
printf '%s' '西梅田 禅園' > "$TXTDIR/title.txt"
printf '%s' '〒530-0001 大阪府大阪市北区梅田2-5-25' > "$TXTDIR/addr1.txt"
printf '%s' 'ハービスPLAZA(ハービスOSAKA) B2F' > "$TXTDIR/addr2.txt"
printf '%s' 'TEL  06-6457-1002' > "$TXTDIR/tel.txt"
printf '%s' '営業時間' > "$TXTDIR/hours_label.txt"
printf '%s' 'ランチ   11:00 - 14:45  (L.O.14:00)' > "$TXTDIR/lunch.txt"
printf '%s' 'ディナー 17:30 - 22:00  (L.O.21:00)' > "$TXTDIR/dinner.txt"
printf '%s' '定休日   不定休 (ハービスPLAZA定休日に準ずる)' > "$TXTDIR/closed.txt"
printf '%s' 'サービス料   10％' > "$TXTDIR/service.txt"
printf '%s' '個室使用料   4,500円(税サ込) / 1室' > "$TXTDIR/room.txt"
printf '%s' 'ランチ平均予算   1,200円' > "$TXTDIR/lunch_avg.txt"
printf '%s' 'ご来店、心よりお待ちしております' > "$TXTDIR/footer.txt"

INFO_FILTER=",drawbox=x=0:y=0:w=${W}:h=${H}:color=black@0.6:t=fill"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT':textfile='$TXTDIR/title.txt':fontsize=82:x=(w-text_w)/2:y=210:fontcolor=white:borderw=2:bordercolor=black@0.5"
INFO_FILTER="${INFO_FILTER},drawbox=x=440:y=340:w=200:h=2:color=white@0.7:t=fill"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT_REG':textfile='$TXTDIR/addr1.txt':fontsize=28:x=(w-text_w)/2:y=400:fontcolor=white@0.95"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT_REG':textfile='$TXTDIR/addr2.txt':fontsize=28:x=(w-text_w)/2:y=445:fontcolor=white@0.95"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT':textfile='$TXTDIR/tel.txt':fontsize=40:x=(w-text_w)/2:y=520:fontcolor=white"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT':textfile='$TXTDIR/hours_label.txt':fontsize=32:x=(w-text_w)/2:y=620:fontcolor=white@0.9"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT_REG':textfile='$TXTDIR/lunch.txt':fontsize=28:x=(w-text_w)/2:y=675:fontcolor=white@0.95"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT_REG':textfile='$TXTDIR/dinner.txt':fontsize=28:x=(w-text_w)/2:y=720:fontcolor=white@0.95"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT_REG':textfile='$TXTDIR/closed.txt':fontsize=26:x=(w-text_w)/2:y=780:fontcolor=white@0.9"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT_REG':textfile='$TXTDIR/service.txt':fontsize=26:x=(w-text_w)/2:y=850:fontcolor=white@0.9"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT_REG':textfile='$TXTDIR/room.txt':fontsize=26:x=(w-text_w)/2:y=895:fontcolor=white@0.9"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT_REG':textfile='$TXTDIR/lunch_avg.txt':fontsize=26:x=(w-text_w)/2:y=940:fontcolor=white@0.9"
INFO_FILTER="${INFO_FILTER},drawbox=x=440:y=1050:w=200:h=2:color=white@0.7:t=fill"
INFO_FILTER="${INFO_FILTER},drawtext=fontfile='$FONT_REG':textfile='$TXTDIR/footer.txt':fontsize=28:x=(w-text_w)/2:y=1100:fontcolor=white@0.9"

ffmpeg -y -loglevel error \
  -i "$INFO_IMG" \
  -filter_complex "
    [0:v]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},format=yuv420p,
      zoompan=z='min(zoom+0.0008,1.05)':d=${INFO_FRAMES}:s=${W}x${H}:fps=${FPS}
      ${INFO_FILTER},
      fade=t=in:st=0:d=${FADE},fade=t=out:st=$(awk -v d=$INFO_DUR -v f=$FADE 'BEGIN{print d-f}'):d=${FADE}
  " \
  -t ${INFO_DUR} -c:v libx264 -pix_fmt yuv420p -r ${FPS} "$INFO_OUT"
i=$((i+1))

# === QR final card ===
QR_DUR=5.0
QR_IMG="西梅田QR文字入り.jpg"
QR_OUT=$(printf "video_work/clips/clip_%02d.mp4" $i)
echo "=== Building $QR_OUT (QR card) ==="
ffmpeg -y -loglevel error \
  -loop 1 -t ${QR_DUR} -r ${FPS} -i "$QR_IMG" \
  -filter_complex "
    [0:v]scale=${W}:${H}:force_original_aspect_ratio=increase,crop=${W}:${H},format=yuv420p,
      fade=t=in:st=0:d=${FADE},fade=t=out:st=$(awk -v d=$QR_DUR -v f=$FADE 'BEGIN{print d-f}'):d=${FADE}
  " \
  -t ${QR_DUR} -r ${FPS} -c:v libx264 -pix_fmt yuv420p "$QR_OUT"

# concat
LIST=video_work/concat.txt
> "$LIST"
for c in video_work/clips/clip_*.mp4; do
  echo "file '$(realpath $c)'" >> "$LIST"
done

ffmpeg -y -loglevel error -f concat -safe 0 -i "$LIST" -c copy video_work/final.mp4

ffmpeg -y -loglevel error -f lavfi -i anullsrc=channel_layout=stereo:sample_rate=44100 -i video_work/final.mp4 \
  -shortest -c:v copy -c:a aac -b:a 128k Settai_Reels.mp4

echo "=== DONE ==="
ls -la Settai_Reels.mp4
