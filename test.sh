#!/bin/bash
#--------------------------------
# A script for running the graphlab Netflix simulation
# using multithreading (not OpenMPI)
#----------------------------------
#SBATCH -J platy_tests
#SBATCH -o platy_tests.o%j
#SBATCH -e platy_tests.o%j
#SBATCH -p normal
#SBATCH -N 1
#SBATCH -n 4
#SBATCH -t 2:00:00
#SBATCH -A iPlant-Collabs

## Do some SBATCH-specific module loads and variable definitions here
module purge
module load TACC
module load launcher
module load python
refFile="e_coli_idx.fa"
bamFile="ecoli_sorted.bam"

## Set up the bin directory
tar xzf bin.tgz
cd ./bin
./simlink.sh
cd ..
PATH=$PATH:`pwd`/bin

## Inputs: queryBAM,
##         fasta file OR flat tgz/tar.gz file with fa and fai
QBAM=$bamFile
QBAMIND=$bamInd
if [ -n "${output}" ]
then
  output="--output ${output}"
else
  output=""
fi
nCPU="--nCPU 4"
CPUS=4
#extractRef.sh ${refFile}
#REFERENCE_F=$(basename $(find ${TARGET}/ -name "*.${EXTENSION}" -print0))
if [ ! -a ${refFile}i ]
then
    samtools faidx $refFile
fi
REFERENCE_F="--refFile $refFile"

WHOLEGENOME=0
if [ -z `echo ${regions} | sed "s/ //g"` ]
    then REGIONS=""; WHOLEGENOME=1
else
    REGIONS="--regions ${regions}"
fi

if [ -z `echo ${source} | sed "s/ //g"` ]
    then SOURCE=""
else
    SOURCE="--source ${source}"
fi

rm -rf paramlist.txt
## Run Platypus on the input files
if [ "$WHOLEGENOME" -eq "0" ]
    then
    ##Run platypus on the specified region
    nCPU=8
    ARGS="${output} ${REFERENCE_F} "
    ARGS+="${QBAM} ${REGIONS} ${assemble} ${SOURCE} ${nCPU} ${logFileName} "
    ARGS+="${bufferSize} ${minReads} ${maxReads} ${maxVariants} ${verbosity} "
    ARGS+="${minPosterior} ${maxSize} ${minFlank}"
    python ./bin/Platypus.py callVariants ${ARGS}
else
    ## get BAM header line and find genomic length
    seqID=`samtools view -H ${QBAM} | grep "SQ" | cut -f 2 | awk -F':' '{print $2}'`
    genomeLen=`samtools view -H ${QBAM} | grep -o "LN:[0-9]*" | grep -o "[0-9]*"`
    ## Divide the genome up into portions that give each core 1,000,000bp
    numWorkers=$((${genomeLen}/1000000))
    remainder=$((${genomeLen}%1000000))
    for i in `seq 1 $numWorkers`
    do
        REGIONS=$seqID:$((`expr $i - 1` * 1000000))-$(($i * 1000000))
        ARGS="--output temp${i}.vcf ${REFERENCE_F} "
        ARGS+=" --bamFiles ${QBAM} --regions ${REGIONS} ${assemble} ${SOURCE} ${nCPU} ${logFileName} "
        ARGS+="${bufferSize} ${minReads} ${maxReads} ${maxVariants} ${verbosity} "
        ARGS+="${minPosterior} ${maxSize} ${minFlank}"
        echo "python ./bin/Platypus.py callVariants  ${ARGS}" >> paramlist.txt
    done
    REGIONS=$seqID:$(($i * 1000000))-$(($i * 1000000 + $remainder))
    ARGS="--output temp$((${i} + 1)).vcf ${REFERENCE_F} "
    ARGS+="--bamFiles ${QBAM} --regions ${REGIONS} ${assemble} ${SOURCE} ${nCPU} ${logFileName} "
    ARGS+="${bufferSize} ${minReads} ${maxReads} ${maxVariants} ${verbosity} "
    ARGS+="${minPosterior} ${maxSize} ${minFlank}"
    echo "python ./bin/Platypus.py callVariants ${ARGS}" >> paramlist.txt

    echo "Launcher...."
    date
    export TACC_LAUNCHER_SCHED=dynamic
    EXECUTABLE=$TACC_LAUNCHER_DIR/init_launcher
    $TACC_LAUNCHER_DIR/paramrun $EXECUTABLE paramlist.txt
    date
    echo "..Done"

fi


# Merge temp VCFs into final output

## Clean up the inputs and remove the bin directory
for i in ${TARGET} .launcher $QBAM $QBAMIND bin paramlist.txt temp*
do
    echo "Removing ${i}"
    #rm -rf $i
done
