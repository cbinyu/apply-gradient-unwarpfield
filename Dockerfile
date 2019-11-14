###   Start by creating a "builder"   ###
# We'll compile all needed packages in the builder, and then
# we'll just get only what we need for the actual APP

ARG FSLIMAGE_VERSION=v2.0

# Use CBI's BIDSApp_builder as a parent image:
ARG BIDSAPP_BUILDER_VERSION=v1.5
FROM cbinyu/bidsapp_builder:${BIDSAPP_BUILDER_VERSION} as builder

###   Clean up a little   ###

# Get rid of some Python packages not needed by our App:
# (There is nothing else to clean for this App, since we haven't
#  installed anything new).


#############

FROM cbinyu/fsl6-core:${FSLIMAGE_VERSION} as fsl_builder

###  Now, get a new machine with only the essentials,   ###
###    copy from the builder stage and fsl6-core what's ###
###    needed and add the BIDS-Apps wrapper (run.py)    ###
FROM cbinyu/bidsapp_builder:${BIDSAPP_BUILDER_VERSION} as Application

# Note: this is the FSL directory in cbinyu/fsl6-core:
ENV FSLDIR=/usr/local/fsl/ \
    FSLOUTPUTTYPE=NIFTI_GZ
ENV PATH=${FSLDIR}/bin:$PATH \
    LD_LIBRARY_PATH=${FSLDIR}:${LD_LIBRARY_PATH}

# Copy any extra python packages installed in the builder stage:
# (Note the variable ${PYTHON_LIB_PATH} is defined in the bidsapp_builder container)
# (Nothing to copy for this App, since we haven't installed anything new)
#COPY --from=builder ./${PYTHON_LIB_PATH}/site-packages/      ${PYTHON_LIB_PATH}/site-packages/
#COPY --from=builder ./usr/local/bin/           /usr/local/bin/

# Copy FSL binaries needed by our App:
COPY --from=fsl_builder ./${FSLDIR}/bin/flirt \
                        ./${FSLDIR}/bin/convert_xfm \
                        ./${FSLDIR}/bin/fslorient \
                        ./${FSLDIR}/bin/convertwarp \
                        ./${FSLDIR}/bin/fslmaths \
                        ./${FSLDIR}/bin/fslsplit \
                        ./${FSLDIR}/bin/applywarp \
                        ./${FSLDIR}/bin/fslhd \
                        ./${FSLDIR}/bin/fslval \
                        ./${FSLDIR}/bin/zeropad \
                        ./${FSLDIR}/bin/fslmerge \
                               ${FSLDIR}/bin/
# The following copies both libraries to the $FSLDIR/lib folder:
COPY --from=fsl_builder ./${FSLDIR}/lib/libopenblas.so.0 \
                        ./${FSLDIR}/lib/libgfortran.so.3 \
			       ${FSLDIR}/lib/
# Copy an extra library needed by FSL:
COPY --from=fsl_builder ./usr/lib/x86_64-linux-gnu/libquadmath.so.0     \
                        ./usr/lib/x86_64-linux-gnu/libquadmath.so.0.0.0 \
                               /usr/lib/x86_64-linux-gnu/

COPY run.py version prisma_gradunwarp.sh /
RUN chmod a+rx /run.py /version /prisma_gradunwarp.sh

ENTRYPOINT ["/run.py"]
