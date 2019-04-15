###   Start by creating a "builder"   ###
# We'll compile all needed packages in the builder, and then
# we'll just get only what we need for the actual APP

# Use an official Python runtime as a parent image
FROM python:3.5-slim as builder

## install:
# -curl, tar, unzip (to get the BIDS-Validator)
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    curl \
    tar \
    unzip \
  && apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y


###   Install BIDS-Validator   ###

# Install nodejs and bids-validator from npm:
RUN apt-get update -qq && apt-get install -y gnupg && \
    curl -sL https://deb.nodesource.com/setup_8.x | bash - && \
    apt-get update -qq && apt-get install -y nodejs && \
    apt-get clean -y && apt-get autoclean -y && apt-get autoremove -y && \
  npm install -g bids-validator


###   Install PyBIDS   ###

RUN pip install pybids

###   Clean up a little   ###

# Get rid of some test folders in some of the Python packages:
# (They are not needed for our APP):
RUN rm -fr /usr/local/lib/python3.5/site-packages/nibabel/nicom/tests && \
    rm -fr /usr/local/lib/python3.5/site-packages/nibabel/tests       && \
    rm -fr /usr/local/lib/python3.5/site-packages/nibabel/gifti/tests    \
    # Remove scipy, because we really don't need it.                     \
    # I'm leaving the EGG-INFO folder because Nipype requires it.        \
    && rm -fr /usr/local/lib/python3.5/site-packages/scipy-1.1.0-py3.5-linux-x86_64.egg/scipy



#############

###  Now, get a new machine with only the essentials  ###
###       and add the BIDS-Apps wrapper (run.py)      ###
FROM python:3.5-slim as Application

ENV FSLDIR=/usr/local/fsl/ \
    FSLOUTPUTTYPE=NIFTI_GZ
ENV PATH=${FSLDIR}/bin:$PATH \
    LD_LIBRARY_PATH=${FSLDIR}:${LD_LIBRARY_PATH}


COPY --from=builder ./usr/local/lib/python3.5/ /usr/local/lib/python3.5/
COPY --from=builder ./usr/local/bin/           /usr/local/bin/
# Copy FSL binaries needed by our App:
COPY --from=cbinyu/fsl6-core ./usr/local/fsl/bin/flirt \
                             ./usr/local/fsl/bin/convert_xfm \
                             ./usr/local/fsl/bin/fslorient \
                             ./usr/local/fsl/bin/convertwarp \
                             ./usr/local/fsl/bin/fslmaths \
                             ./usr/local/fsl/bin/fslsplit \
                             ./usr/local/fsl/bin/applywarp \
                             ./usr/local/fsl/bin/fslhd \
                             ./usr/local/fsl/bin/fslval \
                             ./usr/local/fsl/bin/zeropad \
                             ./usr/local/fsl/bin/fslmerge \
                                    ${FSLDIR}/bin/
# Copy FSL libraries needed by our App (these are libraries distributed
#   with FSL)
COPY --from=cbinyu/fsl6-core ./usr/local/fsl/lib/libopenblas.so.0 \
                             ./usr/local/fsl/lib/libgfortran.so.3 \
                                    ${FSLDIR}/lib/
COPY --from=builder ./usr/lib/x86_64-linux-gnu /usr/lib/
COPY --from=builder ./usr/bin/                 /usr/bin/
COPY --from=builder ./usr/lib/node_modules/bids-validator/    /usr/lib/node_modules/bids-validator/
# Copy an extra library needed by FSL:
COPY --from=cbinyu/fsl6-core ./usr/lib/x86_64-linux-gnu/libquadmath.so.0     \
     			     ./usr/lib/x86_64-linux-gnu/libquadmath.so.0.0.0 \
                                    /usr/lib/x86_64-linux-gnu/

COPY run.py version prisma_gradunwarp.sh /
RUN chmod a+rx /run.py /version /prisma_gradunwarp.sh

ENTRYPOINT ["/run.py"]
