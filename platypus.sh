## Split files by chromosome region using GTK, UNLESS
## a specific region is passed in as an argument
if [ -d ${regions} ]

## Take in and assemble argument string
ARGS= ${output} ${refFile} ${bamFiles} ${regions} ${assemble}
ARGS+= ${source} ${nCPU} ${logFileName} ${bufferSize} ${minReads}
ARGS+= ${maxReads} ${maxVariants} ${verbosity} ${minPosterior}
ARGS+= ${maxSize} ${minFlank}
## Unpack reference if necessary

## Handling paired-end data

## Run Platypus on the input files
python platypus ${ARGS}

## Clean up the inputs and remove the bin directory
