data=ecoli.bam
ref=ecoli_idx

python Platypus.py --output out.txt --nCPU 4 --refFile $ref --bamFiles $data
