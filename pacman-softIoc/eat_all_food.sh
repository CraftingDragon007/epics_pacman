for y in {1..9}
do
  for x in {1..28}
  do
    if [ $x -lt 21 ] || [ $y -ne 9 ]; then
      caput PACMAN:VIS_${x}_${y} 0
    fi
  done
done