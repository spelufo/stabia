FROM julia:1.10

ARG UID=1000

# Add a regular user.
RUN groupadd stabia -g ${UID} && useradd stabia -u ${UID} -g ${UID} -m -s /bin/bash

# Install stabia


ENV VESUVIUS_DATA_DIR=/mnt/vesuvius/data
RUN mkdir -p /mnt/vesuvius/data && chown -R ${UID}:${UID} /mnt/vesuvius

RUN mkdir -p /opt/stabia && chown -R ${UID}:${UID} /opt/stabia
COPY --chown=${UID}:${UID} envs/grids/Project.toml envs/grids/Manifest.toml  /opt/stabia/
USER stabia
WORKDIR /opt/stabia
RUN julia --project=. -e 'using Pkg; Pkg.instantiate()'
COPY --chown=${UID}:${UID} src  /opt/stabia/src
COPY --chown=${UID}:${UID} envs/grids/stabia.jl  /opt/stabia/src/stabia.jl
COPY --chown=${UID}:${UID} envs/grids/build.jl  /opt/stabia/src/build/build.jl
COPY --chown=${UID}:${UID} LICENSE  /opt/stabia/

ENTRYPOINT ["julia", "--project=."]
