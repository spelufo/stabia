FROM julia:1.10

# Add a regular user.
RUN groupadd stabia -g 1000 && useradd stabia -u 1000 -g 1000 -m -s /bin/bash

# Install stabia

ENV VESUVIUS_DATA_DIR=/mnt/vesuvius/data
RUN mkdir -p /mnt/vesuvius/data && chown -R 1000:1000 /mnt/vesuvius

RUN mkdir -p /opt/stabia && chown -R 1000:1000 /opt/stabia
COPY --chown=1000:1000 envs/grids/Project.toml envs/grids/Manifest.toml  /opt/stabia/
USER stabia
WORKDIR /opt/stabia
RUN julia --project=. -e 'using Pkg; Pkg.instantiate()'
COPY --chown=1000:1000 src  /opt/stabia/src
COPY --chown=1000:1000 envs/grids/stabia.jl  /opt/stabia/src/stabia.jl
COPY --chown=1000:1000 envs/grids/build.jl  /opt/stabia/src/build/build.jl
COPY --chown=1000:1000 LICENSE  /opt/stabia/

ENTRYPOINT ["julia", "--project=."]
