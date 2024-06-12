FROM biocontainers/ilastik:1.4.0_cv2 AS ilastik

FROM julia:1.9

# Add a regular user.
RUN groupadd stabia -g 1000 && useradd stabia -u 1000 -g 1000 -m -s /bin/bash

# Install ilastik
# ARG ilastik_version
# ADD https://files.ilastik.org/ilastik-${ilastik_version}-Linux.tar.bz2 /
# RUN tar -xzf ilastik-${ilastik_version}-Linux.tar.bz2 && mkdir -p /opt && mv ilastik-${ilastik_version}-Linux /opt/ilastik && rm ilastik-${ilastik_version}-Linux.tar.bz2
# The dowload from ilastik.org was taking hours so we pull it from this other docker container instead.
COPY --from=ilastik /opt/ilastik-1.4.0-Linux /opt/ilastik

# Install stabia

ENV VESUVIUS_DATA_DIR=/mnt/vesuvius/data
ENV VESUVIUS_ILASTIK_DIR=/mnt/vesuvius/ilastik
RUN mkdir -p /mnt/vesuvius/{data,ilastik} && chown -R 1000:1000 /mnt/vesuvius
COPY --chown=1000:1000 ilastik/* /mnt/vesuvius/ilastik/

RUN mkdir -p /opt/stabia && chown -R 1000:1000 /opt/stabia
COPY --chown=1000:1000 dev.sh Project.toml Manifest.toml LICENSE /opt/stabia/

USER stabia
WORKDIR /opt/stabia
RUN julia --project=. -e 'using Pkg; Pkg.instantiate()'

COPY --chown=1000:1000 src /opt/stabia/src

ENTRYPOINT ["julia", "--project=."]
