#!/usr/bin/env python3
import argparse
import os
import subprocess
from glob import glob
from bids import BIDSLayout
import pdb

__version__ = open(os.path.join(os.path.dirname(os.path.realpath(__file__)),
                                'version')).read()

def run(command, env={}):
    merged_env = os.environ
    merged_env.update(env)
    print(command)
#        try:
#            completed = subprocess.Popen(
#                command,
#                shell=True,
#                stdout=subprocess.PIPE,
#                stderr=subprocess.STDOUT,
#                env=merged_env
#            )
#        except subprocess.CalledProcessError as err:
#            print('ERROR:', err)
#        else:
#            print( completed.stdout.decode('utf-8') )
    process = subprocess.Popen(command, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, shell=True,
                                env=merged_env)
    while True:
        line = process.stdout.readline()
        line = str(line, 'utf-8')[:-1]
        print(line)
        if line == '' and process.poll() != None:
            break
    if process.returncode != 0:
        raise Exception("Non zero return code: %d"%process.returncode)


parser = argparse.ArgumentParser(description='Apply-gradient-unwarpfield BIDS App')
parser.add_argument('bids_dir', help='The directory with the input dataset '
                    'formatted according to the BIDS standard.')
parser.add_argument('output_dir', help='The directory where the output files '
                    'should be stored.')
parser.add_argument('analysis_level', help='Level of the analysis that will be performed. '
                    'Multiple participant level analyses can be run independently '
                    '(in parallel) using the same output_dir.',
                    choices=['participant'])
parser.add_argument('--participant_label', help='The label(s) of the participant(s) that should be analyzed. The label '
                   'corresponds to sub-<participant_label> from the BIDS spec '
                   '(so it does not include "sub-"). If this parameter is not '
                   'provided all subjects should be analyzed. Multiple '
                   'participants can be specified with a space separated list.',
                   nargs="+")
parser.add_argument('--n_cpus', help='Number of CPUs/cores available to use.',
                    default=1, type=int)
parser.add_argument('--full_warp_folder', help='Full path to the folder that has both the neurological_ '
                    'and radiological_fullWarp_abs NIfTI images.',
                    required=True)
parser.add_argument('--output_suffix', help='Suffix to be added to each of the input filenames for '
                    'the output files (e.g. if the output_suffix is "_gdc", the output corresponding '
                    'to "myT1.nii.gz" will be "myT1_gdc.nii.gz").  Default: "_gdc"',
                    default='_gdc', type=str)
parser.add_argument('--skip_bids_validator', help='Whether or not to perform BIDS dataset validation',
                   action='store_true')
parser.add_argument('-v', '--version', action='version',
                    version='BIDS-App apply-gradient-unwarpfield version {}'.format(__version__))


args = parser.parse_args()

# Check that the full-warp-folder exists and it has both the
# neurological_ and radiological_fullWarp_abs NIfTI images:
if not os.path.isdir(args.full_warp_folder):
    raise AssertionError('--full-warp-folder does not exist.')
else:
    files_to_find = ['radiological_fullWarp_abs.nii*', 'neurological_fullWarp_abs.nii*']
    if not all([ glob(os.path.join(args.full_warp_folder, f)) for f in files_to_find ]):
        raise AssertionError('--full_warp_folder does not include radiological_fullWarp_abs and radiological_fullWarp_abs NIfTI files.')

# if "output_suffix" argument doesn't starts with underscore ("_"), add it:
if args.output_suffix[0] != '_':
    args.output_suffix = "_" + args.output_suffix

if not args.skip_bids_validator:
    run('bids-validator %s'%args.bids_dir)

layout = BIDSLayout(args.bids_dir, ignore=['derivatives'])
subjects_to_analyze = []
# only for a subset of subjects
if args.participant_label:
    subjects_to_analyze = args.participant_label
# for all subjects
else:
    subject_dirs = glob(os.path.join(args.bids_dir, "sub-*"))
    subjects_to_analyze = [subject_dir.split("-")[-1] for subject_dir in subject_dirs]

# running participant level
if args.analysis_level == "participant":

    for subject_label in subjects_to_analyze:
        print("Subject: %s"%subject_label)

        # get all images for this subject:
        myImages = layout.get(subject=subject_label,
                                  extension=["nii.gz", "nii"],
                                  return_type='file')
        if (len(myImages) == 0):
            print("No images found for subject " + subject_label)

        outDir = os.path.join( args.output_dir, "sub-" + subject_label )
        if not os.path.isdir( outDir ):
            os.makedirs( outDir )

        # we'll be running the unwarping processes in parallel, so create a set of subprocesses:
        processes = set()
        
        for myImage in myImages:
            #print( myImage )
            # portion of myImage path after the folder "sub-subject_label" (e.g., "anat/sub-..."):
            # (note: we leave the last argument to os.path.join empty so that it adds a trailing
            #  directory separator to the .split argument)
            subject_to_image_path = myImage.split( os.path.join(args.bids_dir, "sub-" + subject_label, "") )[1]
            # remove extension (we first remove '.gz', if present):
            subject_to_image_path = os.path.splitext(subject_to_image_path.split('.gz')[0])[0]

            outImage = os.path.join( outDir, subject_to_image_path + args.output_suffix )
            #print( 'outImage: ' +  outImage )
            # we'll also save the warp:
            outWarpDir = os.path.join( outDir,
                                       os.path.dirname(subject_to_image_path),
                                       'xfm' )
            if not os.path.isdir( outWarpDir ):
                os.makedirs( outWarpDir )
            outWarp = os.path.join( outWarpDir,
                                    os.path.basename(subject_to_image_path) + args.output_suffix + "_warp" )
            #print( 'outWarp: ' + outWarp )
            
            ###   call the unwarping script:   ###
            # first, we generate the commands:
            cmd1 = "/prisma_gradunwarp.sh -i " + myImage + \
                                        " -o " + outImage + \
                                        " -wf " + args.full_warp_folder
            #print( "cmd1: " + cmd1)
            # move the warp field to the corresponding folder:
            cmd2 = "mv " + outImage + "_warp* " + outWarpDir + os.sep
            #print( "cmd2: " + cmd2)
            #run( cmd1 + "; " + cmd2 )

            outLog = os.path.join( outWarpDir,
                                   os.path.basename(subject_to_image_path) + args.output_suffix + ".log" )
            with open(outLog,"wb") as outF:
                processes.add( subprocess.Popen([cmd1 + "; " + cmd2],
                                                 stdout=outF,
                                                 stderr=outF, shell=True,
                                                 env=os.environ) )
            if len(processes) >= args.n_cpus:
                os.wait()
                processes.difference_update(
                    [p for p in processes if p.poll() is not None])


        # Check if all the child processes were closed:
        for p in processes:
            if p.poll() is None:
                p.wait()


# nothing to run at the group level for this app
