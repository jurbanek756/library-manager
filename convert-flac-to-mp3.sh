cd /Users/jurbanek/Downloads/flac
LINK=false
UNMOUNT=false
while getopts "rluT" option; do
  case $option in
    r)
      rm *_metadata.json
      rm -rf $HOME/Music/Plex
      LINK=true
      if [ -d "/Volumes/MUSIC" ]
      then
        printf "%s\n" "Erasing External USB Flash Drive"
        diskutil reformat /Volumes/MUSIC
      fi
      ;;
    l)
      LINK=true
      ;;
    u)
      UNMOUNT=true
      ;;
    T)
      cd jay
      rm *Z.flac_metadata.json
      if [ -d "/Volumes/MUSIC" ]
      then
        printf "%s\n Erasing External USB Flash Drive"
        diskutil reformat /Volumes/MUSIC
      fi
      ;;
 
    *)
      :
      ;;
  esac
done
i=0
for file in *flac; do 
if [ ! -f "$file"_metadata.json ];
then
  printf "%s\n" $file >> links.txt;
  ffprobe -v quiet -print_format json -show_format -show_streams "$file" >> "$file"_metadata.json;
  ALBUM="$(jq -r '.format.tags.ALBUM' "$file"_metadata.json)"; 
  ALBUM_ARTIST="$(jq -r '.format.tags.album_artist'  "$file"_metadata.json)";
  if [[ "${ALBUM: -1}" == "." ]]; then
    ALBUM_FP="${ALBUM%?}_"
  else
    ALBUM_FP="$ALBUM"
  fi
  echo $ALBUM_FP
  if [[ "${ALBUM_ARTIST: -1}" == "." ]]; then
    ALBUM_ARTISTFP="${ALBUM_ARTIST%?}_"
  else
    ALBUM_ARTISTFP="$ALBUM_ARTIST"
  fi
  echo $ALBUM_ARTISTFP
  TRACK="$(jq -r '.format.tags.track'  "$file"_metadata.json)";
  ARTIST="$(jq -r '.format.tags.ARTIST' "$file"_metadata.json)";
  TITLE="$(jq -r '.format.tags.TITLE' "$file"_metadata.json)";
  DISC="$(jq -r '.format.tags.disc' "$file"_metadata.json)";
  DISCTRIM="$(echo $DISC | sed 's/^0*//')";
  DISC_TOTAL="$(jq -r '.format.tags.DISCTOTAL'  "$file"_metadata.json)";
  DISCTRIM_TOTAL="$(echo $DISC_TOTAL | sed 's/^0*//')";
  YEAR="$(jq -r '.format.tags.YEAR' "$file"_metadata.json)"; 
  GENRE=$(jq -r '.format.tags.GENRE' "$file"_metadata.json | awk -F ', ' 'NF > 1 {print $1} NF == 1 {print $0}') && [ -z "$GENRE" ] && GENRE="$(jq -r '.format.tags.GENRE' "$file"_metadata.json)";
  DECADE=$((YEAR / 10 * 10))
  COMPOSER="$DECADE's Music";
  printf "%s\n" "Adding ID3v2 tags for $file"
  id3v2 -a "$ARTIST" -A "$ALBUM" --TPE2 "$ALBUM_ARTIST" -T "$TRACK" --TPOS "$DISC/$DISC_TOTAL" -t "$TITLE" -y "$YEAR" -g "$GENRE" "$file";
  if [ -d "/Volumes/MUSIC" ] 
  then
    SAMPLE_RATE="$(jq -r '.streams[0].sample_rate'  "$file"_metadata.json)";
    if [ $(expr $SAMPLE_RATE % 48000) -eq 0 ]
    then
      NEW_SAMPLE_RATE=48000;printf "%s\n" "Converting $file to 48kHz mp3 at 320kbps"
    else
      NEW_SAMPLE_RATE=44100;printf "%s\n" "Converting $file to 44.1kHz mp3 at 320kbps"
    fi;
    MP3_FILENAME="$DISC$TRACK ${file%.flac}.mp3" 
    ART_FILENAME="stage.jpg" 
    ffmpeg -y -v quiet -i "$file" -ar $NEW_SAMPLE_RATE -b:a 320k -acodec mp3 stage.mp3;#"$MP3_FILENAME"; 
    ffmpeg -y -v quiet -i "$file" "$ART_FILENAME"; 
    id3v2 -a "$ARTIST" -A "$ALBUM" --TPE2 "$ALBUM_ARTIST" -T "$TRACK" --TPOS "$DISC/$DISC_TOTAL" -t "$TITLE" -y "$YEAR" -g "$GENRE" --TCOM "$COMPOSER" stage.mp3;
    eyeD3 --add-image=$ART_FILENAME:FRONT_COVER stage.mp3 >> cover_art.txt
    printf "%s\n" "Moving $MP3_FILENAME to /Volumes/MUSIC/$ALBUM_ARTIST/$ALBUM"
    mkdir -p /Volumes/MUSIC/"$ALBUM_ARTIST"/"$ALBUM"
    mv  stage.mp3 /Volumes/MUSIC/"$ALBUM_ARTIST"/"$ALBUM"/"$MP3_FILENAME"
  fi;
  M4A_FILENAME="$DISCTRIM-$TRACK ${file%.flac}.m4a" 
  if [ ! -f "$HOME/Music/iTunes/iTunes Media/Music/$ALBUM_ARTISTFP/$ALBUM_FP/$DISCTRIM-$TRACK"* ]
  then
    printf "%s\n" "Converting $file to $M4A_FILENAME and moving to Apple Music";
    ffmpeg -v quiet -y -i "$file" -c:a alac -c:v copy "$M4A_FILENAME";
    id3v2 -1 -a "$ARTIST" -A "$ALBUM" --TPE2 "$ALBUM_ARTIST" -T "$TRACK" --TPOS "$DISC/$DISC_TOTAL" -t "$TITLE" -y "$YEAR" -g "$GENRE" --TCOM "$COMPOSER" "$M4A_FILENAME";
    mv "$M4A_FILENAME" $HOME/Music/iTunes/"iTunes Media"/"Automatically Add to Music.localized"/
  fi;
  if $LINK
  then
    printf "%s\n" "Linking $file to Music Directory for Plex"
    mkdir -p $HOME/Music/Plex/"$COMPOSER"/"$ALBUM_ARTIST"/"$ALBUM"/; ln -s -f "$(pwd)/$file" $HOME/Music/Plex/"$COMPOSER"/"$ALBUM_ARTIST"/"$ALBUM"/
  fi;
  ((i++))
fi;
done;
if [ "$i" -eq 0 ]
then
  printf "%s\n" "Error: No new files to convert."
fi;
if $LINK
then
  curl "http://127.0.0.1:32400/library/sections/2/refresh?X-Plex-Token=shZ72bbxHgErQ-6daUd5"
fi;
if $UNMOUNT
then
  diskutil umount /Volumes/Music
fi;
