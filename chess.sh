#!/bin/bash

# Prompt String leeren und speichern um in am Ende wieder zu setzen
PS1_ORIG=$PS1
PS1=""
# Cursor verstecken, eingabe verstecken und Terminal leeren
tput civis
stty -echo
clear

# Assoziativen Array mit den Farben & Unicode symbolen für jede Figur erstellen
declare -A unicodes=(
  [e]=" "
  [r]="\e[3;94m\u265c"
  [h]="\e[3;94m\u265e"
  [b]="\e[3;94m\u265d"
  [k]="\e[3;94m\u265a"
  [q]="\e[3;94m\u265b"
  [p]="\e[3;94m\u265f"
  [R]="\e[3;31m\u265c"
  [H]="\e[3;31m\u265e"
  [B]="\e[3;31m\u265d"
  [K]="\e[3;31m\u265a"
  [Q]="\e[3;31m\u265b"
  [P]="\e[3;31m\u265f"
)

# board_set
# Setze ein Feld auf eine bestimmte Figur
# Parameter:
#   $1 - x Koordinate für das Feld, das gesetzt werden soll
#   $2 - y Koordinate für das Feld, das gesetzt werden soll
#   $3 - Figur auf die das Feld gesetzt werden soll
board_set() {
  local x=$1
  local y=$2
  board[$x+$y*8]=$3
}

# board_get
# Gibt die Figur zurück, die auf dem angegebenen Feld ist
# Parameter:
#   $1 - x Koordinate für das Feld, das gelesen werden soll
#   $2 - y Koordinate für das Feld, das gelesen werden soll
board_get() {
  local x=$1
  local y=$2
  echo ${board[$x+$y*8]}
}

# draw_board
# Gibt die aktuelle Situation im Terminal aus
draw_board() {
  clear
  echo "Chess"
  echo "It's $turn's turn"
  echo "  A B C D E F G H"
  for ((i=0; i<8; i++)); do
    echo -n "$(( $i+1 )) "
    for ((j=0; j<8; j++)); do
      # Falls das Feld ein gültiger Zug ist, wird es grün
      if [[ ${valid_moves[@]} =~ ($j,$i) ]]; then
        printf "\e[42m"  # Grüner Hintergrund
      # Ansonsten wird es Schachbrett gemustert
      elif (( (i+j) % 2 == 0 )); then
        printf "\e[47m"  # Weisser Hintergrund
      else
        printf "\e[40m"  # Schwarzer Hintergrund
      fi
      printf "${unicodes[${board[$j+$i*8]}]} " # ANSI code + Unicode aus dem oben definierten Array + Leerzeichen ausgeben
    done
    printf "\e[0m\n"  # Farben zurücksetzen und zur nächsten Zeile gehen
  done
}

# get_number
# Gibt die y Koordinate zu den entsprechenden Buchstaben zurück
# Parameter:
#   $1 - Den Buchstaben zu dem man die Y Koordinate braucht
get_number(){
  case $1 in
    "a" | "A" ) echo 0 ;;
    "b" | "B" ) echo 1 ;;
    "c" | "C" ) echo 2 ;;
    "d" | "D" ) echo 3 ;;
    "e" | "E" ) echo 4 ;;
    "f" | "F" ) echo 5 ;;
    "g" | "G" ) echo 6 ;;
    "h" | "H" ) echo 7 ;;
  esac
}

# move
# Bewegt eine Figur von einer zur nächsten Koordinate
# Die Parameter werden aus folgenden globalen Variablen gelesen:
#   $sx - source x ist die x Koordinate vom Ursprungsfeld
#   $sy - source y ist die y Koordinate vom Ursprungsfeld
#   $tx - target x ist die x Koordinate vom Zielfeld
#   $ty - target y ist die y Koordinate vom Zielfeld
move() {
  local piece=$(board_get $sx $sy)
  # Falls ein Bauer das andere Ende des Spiels erreicht, wird er zu einer Dame
  if [[ $piece == "p" && $ty == 8 ]]; then
    piece="q"
  elif [[ $piece == "P" && $ty == 0 ]]; then
    piece="Q"
  fi
  board_set $sx $sy e
  board_set $tx $ty $piece
  draw_board
}

# isCheck
# Kontrolliert ob der angegebene Spieler Schach ist
# Parameter:
#   $1 - Ein 64 Indexes langer array welcher eine Spielposition darstellt
#   $2 - Den Spieler für den kontrolliert werden soll, ob er Schach ist
#        Gültig ist "white" für Weiss und alles andere wird für Schwarz interpretiert
# Gibt 0 zurück, falls der Spieler Schach ist, 1 für nicht Schach.
isCheck() {
  local game=($@)
  if [[ ${game[-1]} = "white" ]]; then
    local searched=k
    local king=K
    local queen=Q
    local horse=H
    local bishop=B
    local rook=R
    local own='^[r|b|h|q|p]$'
  else
    local searched=K
    local king=k
    local queen=q
    local horse=h
    local bishop=b
    local rook=r
    local own='^[R|B|H|Q|P]$'
  fi
  local x
  local y
  # Position des Königs des Spielers, für den kontrolliert wird ob er Schach ist, suchen
  for i in {0..63}; do
    if [[ ${game[$i]} = $searched ]]; then
      x=$((i%8))
      y=$(echo "scale=0; $i / 8" | bc)
      break;
    fi
  done
  # Kontrolliere für ein Bauernschach
  if [[ ${game[-1]} = "white" ]]; then
    if [[ $y < 6 && $x > 0 && ${game[$((x-1+(y+1)*8))]} = P ]]; then return 0; fi
    if [[ $y < 6 && $x < 7 && ${game[$((x+1+(y+1)*8))]} = P ]]; then return 0; fi
  else
    if [[ $y > 1 && $x > 0 && ${game[$((x-1+(y-1)*8))]} = p ]]; then return 0; fi
    if [[ $y > 1 && $x < 7 && ${game[$((x+1+(y-1)*8))]} = p ]]; then return 0; fi
  fi
  # Kontrolliere für ein Springerschach
  if [[ $x > 1 && $y > 0 && ${game[$((x-2+(y-1)*8))]} = "$horse" ]]; then return 0; fi
  if [[ $x > 1 && $y < 7 && ${game[$((x-2+(y+1)*8))]} = "$horse" ]]; then return 0; fi
  if [[ $x > 0 && $y > 1 && ${game[$((x-1+(y-2)*8))]} = "$horse" ]]; then return 0; fi
  if [[ $x > 0 && $y < 6 && ${game[$((x-1+(y+2)*8))]} = "$horse" ]]; then return 0; fi
  if [[ $x < 7 && $y > 1 && ${game[$((x+1+(y-2)*8))]} = "$horse" ]]; then return 0; fi
  if [[ $x < 7 && $y > 0 && ${game[$((x+1+(y-2)*8))]} = "$horse" ]]; then return 0; fi
  if [[ $x < 6 && $y > 0 && ${game[$((x+2+(y-1)*8))]} = "$horse" ]]; then return 0; fi
  if [[ $x < 6 && $y < 7 && ${game[$((x+2+(y+1)*8))]} = "$horse" ]]; then return 0; fi
  # Kontrolliere für Schachs in einer geraden Linie durch einen Turm oder der Dame
  for ((i=$x; i<=7; i++)); do
    if [[ ${game[$((i+y*8))]} =~ $own ]]; then break; fi
    if [[ ${game[$((i+y*8))]} = $rook || ${game[$((i+y*8))]} = $queen ]]; then return 0; fi
  done
  for ((i=$x; i>=0; i--)); do
    if [[ ${game[$((i+y*8))]} =~ $own ]]; then break; fi
    if [[ ${game[$((i+y*8))]} = $rook || ${game[$((i+y*8))]} = $queen ]]; then return 0; fi
  done
  for ((i=$y; i<=7; i++)); do
    if [[ ${game[$((x+i*8))]} =~ $own ]]; then break; fi
    if [[ ${game[$((x+i*8))]} = $rook || ${game[$((x+i*8))]} = $queen ]]; then return 0; fi
  done
  for ((i=$y; i>=0; i--)); do
    if [[ ${game[$((x+i*8))]} =~ $own ]]; then break; fi
    if [[ ${game[$((x+i*8))]} = $rook || ${game[$((x+i*8))]} = $queen ]]; then return 0; fi
  done
  # Kontrolliere für Schachs auf einer diagonalen Linie durch einen Läufer oder der Dame
  for i in {1..7}; do
    if (( $x+$i > 7 || $y+$i > 7 )); then break; fi
    if [[ ${game[$((x+i+(y+i)*8))]} =~ $own ]]; then break; fi
    if [[ ${game[$((x+i+(y+i)*8))]} = $bishop || ${game[$((x+i+(y+i)*8))]} = $queen ]]; then
      return 0
    elif [[ ${game[$((x+i+(y+i)*8))]} != e ]]; then
      break
    fi
  done
  for i in {1..7}; do
    if (( $x+$i > 7 || $y-$i < 0 )); then break; fi
    if [[ ${game[$((x+i+(y-i)*8))]} =~ $own ]]; then break; fi
    if [[ ${game[$((x+i+(y-i)*8))]} = $bishop || ${game[$((x+i+(y-i)*8))]} = $queen ]]; then
      return 0
    elif [[ ${game[$((x+i+(y-i)*8))]} != e ]]; then
      break
    fi
  done
  for i in {1..7}; do
    if (( $x-$i < 0 || $y+$i > 7 )); then break; fi
    if [[ ${game[$((x-i+(y+i)*8))]} =~ $own ]]; then break; fi
    if [[ ${game[$((x-i+(y+i)*8))]} = $bishop || ${game[$((x-i+(y+i)*8))]} = $queen ]]; then
      return 0
    elif [[ ${game[$((x-i+(y+i)*8))]} != e ]]; then
      break
    fi
  done
  for i in {1..7}; do
    if (( $x-$i < 0 || $y-$i < 0 )); then break; fi
    if [[ ${game[$((x-i+(y-i)*8))]} =~ $own ]]; then break; fi
    if [[ ${game[$((x-i+(y-i)*8))]} = $bishop || ${game[$((x-i+(y-i)*8))]} = $queen ]]; then
      return 0
    elif [[ ${game[$((x-i+(y-i)*8))]} != e ]]; then
      break
    fi
  done
  # Kontrolliere für Schachs ausgelöst durch einen andere König
  for i in {-1..1}; do
    if (( $((y+i)) < 0 || $((y+i)) > 7 )); then continue; fi
    for j in {-1..1}; do
      if (( $((x+j)) < 0 || $((x+j)) > 7 || ($i==0 && $j==0) )); then continue; fi
      if [[ ${game[$((x+j+(y+i)*8))]} = $king ]]; then return 0; fi
    done
  done
  return 1
}

# removeCheckMoves
# Iteriert durch $valid_moves und entfernt alle Züge, bei denen der eigene König nach dem
# Zug schach wäre, da dies nicht regelkonform ist
# Parameter:
#   $1 - parameter x ist die x Koordinate der Figur von der die Züge in $valid_moves gemacht werden
#   $2 - parameter y ist die y Koordinate der Figur von der die Züge in $valid_moves gemacht werden
#   $3 - Die Farbe des Spielers für den kontrolliert werden die Schachzüge entfernt werden sollen
#        Gültig ist "white" für Weiss und alles andere wird als Schwarz interpretiert
removeCheckMoves() {
  local cache=()
  local px=$1
  local py=$2
  for p in ${valid_moves[@]}; do # Iteriere durch jeden Zug in $valid_moves
    # Da die $valid_moves das Format x,y haben wird hier der hintere oder fordere Teil entfernt
    # und in einer entsprechenden lokalen Variable gespeichert
    local x=${p%,*}
    local y=${p#*,}
    # Hier wird die aktuelle Spielsituation in den Array $simboard kopiert, damit der Zug simuliert
    # werden kann und dannach geschaut werden kann, ob der Spieler nach diesem Zug Schach wäre
    local simboard=(${board[@]})
    # Falls ein Bauer das andere Ende des Spiels erreicht, wird er zu einer Dame
    local piece=${simboard[$((px+py*8))]}
    if [[ $piece == "p" && $y == 8 ]]; then
      piece="q"
    elif [[ $piece == "P" && $y == 0 ]]; then
      piece="Q"
    fi
    simboard[$((px+py*8))]="e"
    simboard[$((x+y*8))]=$piece
    isCheck "${simboard[@]}" $3
    # falls der Spieler nach dem Zug nicht schach wäre, wird er zu $cache hinzugefügt
    if (( $? != 0 )); then cache+=($p); fi 
  done
  valid_moves=(${cache[@]}) # am Schluss wird $valid_moves mit $cache überschrieben
}

# removeSelfTakingMoves
# Entfernt alle Züge aus $valid_moves welche eine eigene Figur nehmen würden
# Parameter:
#   $1 - Die Farbe des Spielers für den die Züge entfernt werden sollen, mit denen man sich selber nehmen würde
#        Gültig ist "white" für Weiss und alles andere wird als Schwarz interpretiert
removeSelfTakingMoves() {
  local cache=()
  for p in ${valid_moves[@]}; do # Iteriere durch jeden Zug in $valid_moves
    # Kontrolliere mit Regex ob der Zug auf einem Feld mit einer eigenen Figur landen würde
    # Falls nicht wird der Zug zu $cache hinzugefügt
    if [[ $1 == "white" ]]; then
      if [[ ! $(board_get ${p%,*} ${p#*,}) =~ ^[r|b|h|q|k|p]$ ]]; then cache+=($p); fi
    else
      if [[ ! $(board_get ${p%,*} ${p#*,}) =~ ^[R|B|H|Q|K|P]$ ]]; then cache+=($p); fi
    fi
  done
  valid_moves=(${cache[@]}) # am Schluss wird $valid_moves mit $cache überschrieben
}

# getValidMoves
# Setzt $valid_moves auf alle Züge die eine ausgewählte Figur machen darf
# Parameter:
#   $1 - die x Koordinate für die Figur, für welche die erlaubten Züge gesucht werden sollen
#   $2 - die y Koordinate für die Figur, für welche die erlaubten Züge gesucht werden sollen
#   $3 - die Farbe des Spielers für den kontrolliert werden soll, welche Züge erlaubt sind
#        Gültig ist "white" für Weiss und alles andere wird als Schwarz interpretiert
getValidMoves() {
  valid_moves=()
  local x=$1
  local y=$2
  case $(board_get $x $y) in
    # Füge alle gerade Züge für die Dame oder einen Turm hinzu
    "r" | "R" | "q" | "Q" )
      for ((i=$((x+1)); i<=7; i++))
      do
        valid_moves+=($i,$y)
        if [[ $(board_get $i $y) != e ]]; then break; fi
      done
      for ((i=$((x-1)); i>=0; i--))
      do
        valid_moves+=($i,$y)
        if [[ $(board_get $i $y) != e ]]; then break; fi
      done
      for ((i=$((y+1)); i<=7; i++))
      do
        valid_moves+=($x,$i)
        if [[ $(board_get $x $i) != e ]]; then break; fi
      done
      for ((i=$((y-1)); i>=0; i--))
      do
        valid_moves+=($x,$i)
        if [[ $(board_get $x $i) != e ]]; then break; fi
      done
      ;;&
    # Füge alle diagonalen Züge für die Dame oder einen Läufer hinzu
    "b" | "B" | "q" | "Q" )
      for i in {1..7}
      do
        if (( $((x+i)) > 7 || $((y+i)) > 7 )); then break; fi
        valid_moves+=($((x+i)),$((y+i)))
        if [[ $(board_get $((x+i)) $((y+i))) != e ]]; then break; fi
      done
      for i in {1..7}
      do
        if (( $((x-i)) < 0 || $((y-i)) < 0 )); then break; fi
        valid_moves+=($((x-i)),$((y-i)))
        if [[ $(board_get $((x-i)) $((y-i))) != e ]]; then break; fi
      done
      for i in {1..7}
      do
        if (( $((x+i)) > 7 || $((y-i)) < 0 )); then break; fi
        valid_moves+=($((x+i)),$((y-i)))
        if [[ $(board_get $((x+i)) $((y-i))) != e ]]; then break; fi
      done
      for i in {1..7}
      do
        if (( $((x-i)) < 0 || $((y+i)) > 7 )); then break; fi
        valid_moves+=($((x-i)),$((y+i)))
        if [[ $(board_get $((x-i)) $((y+i))) != e ]]; then break; fi
      done
      ;;
    # Füge alle Züge für den König hinzu
    "k" | "K" )
      for i in {-1..1}; do
        if (( $((y+i)) < 0 || $((y+i)) > 7 )); then continue; fi
        for j in {-1..1}; do
          if (( $((x+j)) < 0 || $((x+j)) > 7 || ($i==0 && $j==0) )); then continue; fi
          valid_moves+=($((x+j)),$((y+i)))
        done
      done
      ;;
    # Füge alle Züge für einen weissen Bauern hinzu
    "p" )
      if [[ $(board_get $x $((y+1))) == e ]]; then
        valid_moves+=($x,$((y+1)))
        if [[ $y = 1 && $(board_get $x $((y+2))) = e ]]; then valid_moves+=($x,$((y+2))); fi
      fi
      if [[ $(board_get $((x+1)) $((y+1))) != e ]]; then valid_moves+=($((x+1)),$((y+1))); fi
      if [[ $(board_get $((x-1)) $((y+1))) != e ]]; then valid_moves+=($((x-1)),$((y+1))); fi
      ;;
    # Füge alle Züge für einen schwarzen Bauern hinzu
    "P" )
      if [[ $(board_get $x $((y-1))) == e ]]; then
        valid_moves+=($x,$((y-1)))
        if [[ $y = 6 && $(board_get $x $((y-2))) = e ]]; then valid_moves+=($x,$((y-2))); fi
      fi
      if [[ $((x+1 <= 7)) && $(board_get $((x+1)) $((y-1))) != e ]]; then valid_moves+=($((x+1)),$((y-1))); fi
      if [[ $((x-1 >= 0)) && $(board_get $((x-1)) $((y-1))) != e ]]; then valid_moves+=($((x-1)),$((y-1))); fi
      ;;
    # Füge alle Züge für einen Springer hinzu
    "h" | "H" )
      (( x+2 <= 7 && y-1 >= 0 )) && valid_moves+=($((x+2)),$((y-1)))
      (( x+2 <= 7 && y+1 <= 7 )) && valid_moves+=($((x+2)),$((y+1)))
      (( x+1 <= 7 && y+2 <= 7 )) && valid_moves+=($((x+1)),$((y+2)))
      (( x-1 >= 0 && y+2 <= 7 )) && valid_moves+=($((x-1)),$((y+2)))
      (( x-2 >= 0 && y+1 <= 7 )) && valid_moves+=($((x-2)),$((y+1)))
      (( x-2 >= 0 && y-1 >= 0 )) && valid_moves+=($((x-2)),$((y-1)))
      (( x-1 >= 0 && y-2 >= 0 )) && valid_moves+=($((x-1)),$((y-2)))
      (( x+1 <= 7 && y-2 >= 0 )) && valid_moves+=($((x+1)),$((y-2)))
      ;;
  esac
  removeSelfTakingMoves $3 # Entferne alle Züge, die eine eigene Figur nehmen würden
  removeCheckMoves $x $y $3 # Entferne alle Züge, nach denen der Spieler selbst Schach wäre
}

# hasValidMoves
# Kontrolliert ob ein Spieler noch mindestens einen möglichen Zug hat
# Parameter:
#   $1 - die Farbe des Spielers für den kontrolliert werden soll, ob er noch Züge hat
#        Gültig ist "white" für Weiss und alles andere wird als Schwarz interpretiert
hasValidMoves() {
  if [[ $1 = "white" ]]; then
    local regex='^[r|b|h|q|k|p]$'
  else
    local regex='^[R|B|H|Q|K|P]$'
  fi
  local x
  local y
  for i in {0..63}; do # Iteriere durch jedes Feld auf dem Schachbrett
    if [[ ${board[$i]} =~ $regex ]]; then
      x=$((i%8))
      y=$(echo "scale=0; $i / 8" | bc)
      getValidMoves $x $y $1
      # gebe 0 Zurück sobald die erste Figur mit mindestens einem Zug gefunden wurde
      if [[ ${#valid_moves[@]} > 0 ]]; then return 0; fi
    fi
  done
  return 1 # falls keine Figur mit mindestens einem Zug gefunden wurde 1 zurückgeben
}

# isCheckmate
# Kontrolliert ob ein Spieler Schachmatt ist
# Parameter:
#   $1 - die Farbe des Spielers für den kontrolliert werden soll, ob er Schachmatt ist
#        Gültig ist "white" für Weiss und alles andere wird als Schwarz interpretiert
isCheckmate() {
  # Die Funktion gibt 0 für Schachmatt zurück, falls der Spieler Schach ist und keine gültigen Züge mehr hat
  if [[ $turn = "white" ]]; then
    isCheck "${board[@]}" "black"; local Check=$?
    hasValidMoves "black"; local hasMoves=$?
    if [[ $Check = 0 && $hasMoves = 1 ]]; then return 0; fi
  else
    isCheck "${board[@]}" "white"; local Check=$?
    hasValidMoves "white"; local hasMoves=$?
    if [[ $Check = 0 && $hasMoves = 1 ]]; then return 0; fi
  fi
  return 1
}

# readCoords
# Liest so lange die Koordinaten ein, bis eine gültige x und y Koordinate eingegeben wird
# Das Resultat wird in die globalen Variablen $ix für input x und $iy für input y geschrieben
readCoords() {
  ix=-1
  iy=-1
  while (( iy < 0 || iy > 7 || ix < 0 || ix > 7 )); do # wiederhole bis $ix und $y gültig sind
    read -sN1 input # setze die Variable input auf das erste Zeichen das eingegeben wird
    if [[ $input =~ ^[1-8]$ ]]; then # falls die Eingabe zwischen 1-8 ist es eine y Koordinate
      iy=$((input - 1))
    fi
    if [[ $input =~ ^[a-h|A-H]$ ]]; then # falls die Eingabe zwischen a-h oder A-H ist, ist es eine x Koordinate
      ix=$(get_number $input)
    fi
  done
}

while : # Schleife um mehrere Spiele nacheinander spielen zu können
do
  # Setze den Array $board auf die Startposition
  # Hier steht "e" für empty, die anderen Kleinbuchstaben sind weisse Figuren
  # und die Grossbuchstaben sind die schwarzen Figuren
  # "p" -> Bauer
  # "r" -> Turm
  # "h" -> Springer
  # "b" -> Läufer
  # "q" -> Dame
  # "k" -> König
  board=( \
    "r" "h" "b" "k" "q" "b" "h" "r" \
    "p" "p" "p" "p" "p" "p" "p" "p" \
    "e" "e" "e" "e" "e" "e" "e" "e" \
    "e" "e" "e" "e" "e" "e" "e" "e" \
    "e" "e" "e" "e" "e" "e" "e" "e" \
    "e" "e" "e" "e" "e" "e" "e" "e" \
    "P" "P" "P" "P" "P" "P" "P" "P" \
    "R" "H" "B" "K" "Q" "B" "H" "R" \
  )
  turn="white" # Weiss beginnt
  unset ending # falls das eine zweite Partie ist lösche $ending

  while [ -z "$ending" ] # Schleife für das Spiel selbst
  do
    valid_moves=()
    draw_board
    # wiederhole readCoords so lange, bis eine Figur ausgewählt ist, welche
    # vom Spieler der drann ist bewegt werden darf und mindestens einen möglichen Zug hat
    while : 
    do
      readCoords
      if [[ $turn = "white" ]]; then
        if [[ ! $(board_get $ix $iy) =~ ^[r|b|h|q|k|p]$ ]]; then continue; fi
      else
        if [[ ! $(board_get $ix $iy) =~ ^[R|B|H|Q|K|P]$ ]]; then continue; fi
      fi
      getValidMoves $ix $iy $turn
      if [[ ${#valid_moves[@]} > 0 ]]; then break; fi
    done
    # Setze source x&y auf die oben eingegebenen Koordinaten
    sx=$ix
    sy=$iy
    draw_board # Update die Ausgabe, damit die möglichen Züge sichtbar sind
    # wiederhole readCoords so lange, bis ziel Koordinaten eingegeben werden, zu denen die Ausgewählte Figur gehen kann
    while :
    do
      readCoords
      [[ ${valid_moves[@]} =~ "$ix,$iy" ]] && break
    done
    # Setze target x&y auf die oben eingegebenen Koordinaten
    tx=$ix
    ty=$iy
    move # führe den Zug aus
    valid_moves=() # leere $valid_moves damit die alten nachher nicht mehr angezeigt werden
    draw_board # Update die Ausgabe, damit man den gemachten Zug sieht und die möglichen Züge nicht mehr angezeigt werden
    # Kontrolliere ob der Spieler Schachmatt ist. Falls ja setze $ending und beende die Spiel Schleife.
    isCheckmate
    if [[ $? = 0 ]]; then ending="$turn has won!"; break; fi
    # Kontrolliere ob das Spiel Stalemate ist. Falls ja setze $ending und beende die Spiel Schleife.
    if [[ $turn = "white" ]]; then
      hasValidMoves "black"
    else
      hasValidMoves "white"
    fi
    if [[ $? = 1 ]]; then ending="Stalemate, it's a draw!"; break; fi
    # Wechsle wer drann ist
    [[ $turn = "white" ]] && turn=black || turn=white
  done

  echo $ending "Do you wan't to play again? y/n"
  read -sN1 input
  if [[ $input != y ]]; then break; fi # falls nicht mit "y" geantwortet wird Hauptschleife verlassen
done
# Füge das Resultat in die Datei chess.txt hinzu
echo "========================Chess game========================" >> chess.txt
echo $ending >> chess.txt
echo "Final game position:" >> chess.txt
for i in {0..7}; do
  n=$((i*8))
  echo ${board[n]} ${board[n+1]} ${board[n+2]} ${board[n+3]} ${board[n+4]} ${board[n+5]} ${board[n+6]} ${board[n+7]} >> chess.txt
done
echo "Thanks for playing chess in bash! Your game results are appended in the file chess.txt"
# Cursor, Eingabe und Prompt String wieder auf den Standart setzen
stty echo
tput cnorm
PS1=$PS1_ORIG
