for y in {1..9}
do
  for x in {1..28}
  do
    # check if x < 21 or y != 9
    if [ $x -lt 21 ] || [ $y -ne 9 ]; then
      caput PACMAN:VIS_${x}_${y} 0
    fi
  done
done