## Pydeface BIDS App
This a [BIDS App](https://bids-apps.neuroimaging.io) wrapper that
allows you to apply the warp field needed to correct for the gradient
non-linearities in MRI images.
Like every BIDS App, it consists of a container that includes all of the dependencies and run script that parses a [BIDS dataset](http://bids.neuroimaging.io).
BIDS Apps run on Windows, Linux, Mac as well as HCPs/clusters.


### Description
apply-gradient-unwarpfield BIDS App will grab all the images for a
given subject (or all subjects, if not specified) and apply the
unwarping field neccessary to correct for the gradient non-linearity
distortions.

It requires that you have the (absolute) full warp field --both in
radiological and neurological orientations-- corresponding to your
scanner.

This tool will grab the full warp field and convert it to a relative
warp field corresponding to each of your images Field of View.



### Documentation

### Error Reporting
Experiencing problems? Please open an [issue](http://github.com/cbinyu/apply-gradient-unwarpfield/issues/new) and explain what's happening so we can help.

### Usage
This App has the following command line arguments:

    usage: run.py [-h]
                  [--participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]]
                  --full-warp-folder PATH
                  bids_dir output_dir {participant}

    Example BIDS App entry point script.

    positional arguments:
         bids_dir              The directory with the input dataset formatted
                               according to the BIDS standard.
         output_dir            This argument is here for BIDS-Apps
                               compatibility. All images will be written to the bids_dir
                               overwriting the input.
         {participant}         Level of the analysis that will be performed. Multiple
                               participant level analyses can be run independently
                               (in parallel).

    compulsory argument:
         --full-warp-folder PATH
                               Full path to the folder that has both the neurological_
                               and radiological_fullWarp_abs NIfTI images.

    optional arguments:
         -h, --help            show this help message and exit
         --participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL ...]
                               The label(s) of the participant(s) that should be
                               analyzed. The label corresponds to
                               sub-<participant_label> from the BIDS spec (so it does
                               not include "sub-"). If this parameter is not provided
                               all subjects will be analyzed. Multiple participants
                               can be specified with a space separated list.
         --skip_bids_validator
                               If set, it will not run the BIDS validator before defacing.

To run it in participant level mode (for one participant) in a Docker container:

    docker run -i --rm \
               -v /Users/filo/data/ds005:/bids_dataset \
               cbinyu/apply-gradient-unwarpfield \
                   /bids_dataset \
                   /bids_dataset/derivatives \
                   participant \
                   --participant_label 01 \
                   --full-warp-folder /path/to/fullWarp/folder
