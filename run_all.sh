#!/bin/bash

for f in OBPP/rawdata/sub-OBPP0*/ses-MR*/dwi/sub*_dwi.nii.gz ; do
    dir=`dirname $f`
    sub=`echo ${dir} | sed -e 's,.*sub-,sub-,g' -e 's,/ses.*,,g'`
    ses=`echo $dir | sed -e 's,.*ses-,ses-,g' -e 's,/dwi.*,,g'`
    run=`echo $f | sed -e 's,.*run,run,g' -e 's,_dwi.nii.gz,,g'`

    # interactive mode
    #echo bash 00_run_pipeline.sh $sub $ses $run

    # slurm mode
    echo sbatch sbatch-clem.sh ${sub} ${ses} ${run}
done
