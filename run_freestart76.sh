#!/bin/bash

export BINDIR=$(dirname $0)/bin
export BASESOLGEN=$BINDIR/freestart76_basesolgen
export GPUATTACK=$BINDIR/freestart76_gpuattack

if [ ! -x $BASESOLGEN ]; then
	echo "Cannot find freestart76_basesolgen in $BINDIR"
	exit 1
fi
if [ ! -x $GPUATTACK ]; then
	echo "Cannot find freestart76_gpuattack in $BINDIR"
	exit 1
fi

echo "Generating basesolutions for 4 minutes..."
# Generate base solutions for 4 minutes
SEED=$RANDOM$RANDOM$RANDOM$RANDOM
$BASESOLGEN --seed 1_$SEED -g -m 262144 -o basesol76_1.bin > basesol76_1.log &
$BASESOLGEN --seed 2_$SEED -g -m 262144 -o basesol76_2.bin > basesol76_2.log &
$BASESOLGEN --seed 3_$SEED -g -m 262144 -o basesol76_3.bin > basesol76_3.log &
$BASESOLGEN --seed 4_$SEED -g -m 262144 -o basesol76_4.bin > basesol76_4.log &

echo "4 minutes left..."
for ((i=4; i>=0; --i)); do 
	sleep 60
	echo "$i minutes left..."
done

sleep 5
killall freestart76_basesolgen

# Loop: run GPU attack on available basesolutions, meanwhile generate new basesolutions
for ((i=1;;++i)); do
	# combine generated basesolutions in 1 file
	sleep 2
	inputs=""
	for f in basesol76_*.bin ; do
		inputs="$inputs -i $f"
	done
	if [ -n "$inputs" ]; then
		echo $BASESOLGEN -g -o basesol76.run$i.bin $inputs
		$BASESOLGEN -g -o basesol76.run$i.bin $inputs
	fi
	rm basesol76_*.bin

	# start new generation of basesolutions in background
	SEED=$RANDOM$RANDOM$RANDOM$RANDOM
	$BASESOLGEN --seed 1_${i}_$SEED -g -m 262144 -o basesol76_1.bin >> basesol76_1.log &
	$BASESOLGEN --seed 2_${i}_$SEED -g -m 262144 -o basesol76_2.bin >> basesol76_2.log &
	$BASESOLGEN --seed 3_${i}_$SEED -g -m 262144 -o basesol76_3.bin >> basesol76_3.log &
	$BASESOLGEN --seed 4_${i}_$SEED -g -m 262144 -o basesol76_4.bin >> basesol76_4.log &

	# start timer for 21 minutes
	rm -f basesol76.20min.timer
	(sleep $((21*60)); touch basesol76.20min.timer) &

	# start GPU attack
	$GPUATTACK -a -i basesol76.run$i.bin -o fs76_q56_$i.bin | tee -a fs76_gpu.log
	
	# check for freestart collision
	$BASESOLGEN -v -i fs76_q56_$i.bin > fs76_q56_$i.log
	if grep "Found solution" -A52 -B80 fs76_q56_$i.log ; then
		killall freestart76_basesolgen
		exit 0
	fi
	
	# wait till timer has elapsed if it has not already
	while [ ! -f basesol76.20min.timer ]; do sleep 10; done
	rm -f basesol76.20min.timer
	
	# kill background generation of basesolutions
	killall freestart76_basesolgen
done
