#!/bin/bash

help()
{
    echo "Usage: prisma_gradunwarp -i <input image> -wf <warpfield folder> [-o <output image> (default: input_gdc)] "
    exit
}

outImage=

while [ $# -gt 0 ]
do
    case "$1" in
	-i)
	    inImage=$2
	    shift
	    ;;
	-wf)
	    warpFolder=$(realpath $2)
	    shift
	    ;;
	-o)
	    outImage=$2
	    shift
	    ;;
	*)
	    help
	    ;;
    esac
    shift
done
if [ ${#inImage} -eq 0 ] || [ ${#warpFolder} -eq 0 ]
then
    help
fi
# Make sure inImage exists:
if [ ! -f ${inImage} ] && [ ! -f ${inImage}.nii* ]
then
    echo "${inImage} not found!"
    exit
fi

# Error checks for warpFolder:
# TODO

# remove NIfTI extension:
inImage=${inImage%.nii*}

if [ ${#outImage} -eq 0 ]
then
    outImage=${inImage}_gdc
fi

# Output warp field:
outWarp=${outImage}_warp


# Pick the warp field corresponding to this image type (neuro-/radiological):
if [[ $(${FSLDIR}/bin/fslorient -getorient $inImage) == "NEUROLOGICAL" ]]
then
  unwarp_field=neurological_fullWarp_abs
else
  unwarp_field=radiological_fullWarp_abs
fi

# Temporary working directory:
tmpDir=$(mktemp -d /tmp/prisma_unwarp.XXXXX)

echo "Computing relative warp field for input image..."

# Compute the rigid transformation matrix between the full FoV and the original image:
${FSLDIR}/bin/flirt -in ${warpFolder}/${unwarp_field} -ref $inImage -omat ${tmpDir}/inImage_to_fullWarp.mat -applyxfm -usesqform
${FSLDIR}/bin/convert_xfm -omat ${tmpDir}/inImage_to_fullWarp_inv.mat -inverse ${tmpDir}/inImage_to_fullWarp.mat 

# Compute the relative warp in the original image orientation:
${FSLDIR}/bin/convertwarp --abs --ref=$inImage --premat=${tmpDir}/inImage_to_fullWarp_inv.mat --warp1=${warpFolder}/${unwarp_field} --postmat=${tmpDir}/inImage_to_fullWarp.mat --relout --out=$outWarp --jacobian=${outWarp}_jacobian

# convertwarp's jacobian output has 8 frames, each combination of one-sided differences, so average them
${FSLDIR}/bin/fslmaths ${outWarp}_jacobian -Tmean ${outWarp}_jacobian

###  Apply the warp:  ###

echo "Applying the warp:"
# applywarp uses TONS of memory, so split by volumes:
#${FSLDIR}/bin/applywarp --rel --interp=spline -i $f -r $f -w $OutputTransformFile -o $out_f

${FSLDIR}/bin/fslsplit ${inImage} ${tmpDir}/vol -t
FrameMergeSTRING=""
NumFrames=`${FSLDIR}/bin/fslval ${inImage} dim4`
for ((k=0; k < $NumFrames; k++)); do

  if [[ $(($k % 10)) -eq 0 ]]; then echo "Volume $k..."; fi
    
  vnum=`${FSLDIR}/bin/zeropad $k 4`
  # Note: we need to use as reference image one with a single volume; otherwise
  #  the output volume will have NumFrames volumes.
  ${FSLDIR}/bin/applywarp --rel --interp=spline -i ${tmpDir}/vol$vnum -r ${tmpDir}/vol0000 -w $outWarp -o ${tmpDir}/out_vol$vnum
  FrameMergeSTRING="${FrameMergeSTRING}${tmpDir}/out_vol$vnum.nii* "
done


# Get the original TR:
TR_vol=`${FSLDIR}/bin/fslval ${inImage} pixdim4 | cut -d " " -f 1`

# Merge output volumes:
#echo "mergeString:"
#echo "$FrameMergeSTRING"
${FSLDIR}/bin/fslmerge -tr ${outImage} $FrameMergeSTRING $TR_vol

# Cleanup:
rm -fr $tmpDir

