# ABIDES — Linux container for the "Build and Battle Your Trading Agent" lab.
#
# Designed to give every student (Mac Intel, Apple Silicon, or Windows) the
# same Python 3.9 environment without "works on my machine" issues.
#
# Two ways to use this image:
#   1. VS Code "Reopen in Container" (.devcontainer/devcontainer.json)
#      → drops you into a shell with the source bind-mounted in editable mode.
#   2. `docker compose up`
#      → starts JupyterLab on http://localhost:8888.

FROM python:3.9-slim-bookworm

# --- System-level build deps -------------------------------------------------
# Needed by numba/llvmlite, lz4, ormsgpack, pomegranate, and friends.
# `make` and `git` are conveniences for in-container workflows.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        make \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# --- Non-root user -----------------------------------------------------------
# Linux hosts mount bind volumes with the host UID; running as root would create
# files students can't edit from their host shell. Docker Desktop on Mac/Windows
# handles UID mapping transparently, so this is a Linux-host courtesy.
ARG USERNAME=abides
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid ${USER_GID} ${USERNAME} \
 && useradd  --uid ${USER_UID} --gid ${USER_GID} --create-home --shell /bin/bash ${USERNAME}

WORKDIR /abides

# --- Python dependencies -----------------------------------------------------
# Copy dependency declarations first so Docker can cache the (slow) pip layer
# between rebuilds when only source changes.
#
# Two paths:
#   1. requirements.lock present → fully-pinned, reproducible install.
#   2. requirements.lock absent  → bootstrap from requirements.in /
#      requirements-dev.in. Used when first cloning the repo before
#      `make lock` has ever run.
#
# The sub-package setup.cfg files are copied so editable installs pick up the
# install_requires declared there. With the lockfile present, `--no-deps` keeps
# the resolver from drifting away from the pinned set.
COPY requirements.in requirements-dev.in ./
COPY requirements.lock* ./
COPY abides-core/setup.cfg    abides-core/setup.cfg
COPY abides-core/setup.py     abides-core/setup.py
COPY abides-markets/setup.cfg abides-markets/setup.cfg
COPY abides-markets/setup.py  abides-markets/setup.py
COPY abides-gym/setup.cfg     abides-gym/setup.cfg
COPY abides-gym/setup.py      abides-gym/setup.py

RUN pip install --no-cache-dir --upgrade pip setuptools wheel \
 && if [ -f requirements.lock ]; then \
        echo "Installing from requirements.lock (reproducible)" && \
        pip install --no-cache-dir -r requirements.lock ; \
    else \
        echo "No requirements.lock found — bootstrapping from .in files" && \
        pip install --no-cache-dir -r requirements.in -r requirements-dev.in ; \
    fi

# --- ABIDES sub-packages (editable) -----------------------------------------
# Copy each sub-package's source tree and install in editable mode so source
# edits in the bind-mounted /abides take effect without a rebuild.
COPY abides-core/    abides-core/
COPY abides-markets/ abides-markets/
COPY abides-gym/     abides-gym/

# In the lockfile path, all deps were already installed above; here pip just
# registers the editable links and confirms install_requires is satisfied.
# In the bootstrap path, the editable installs pull each sub-package's deps
# (numpy, pandas, scipy, gym, pomegranate, coloredlogs) — that's the only
# place those land before a lockfile exists.
RUN pip install --no-cache-dir -e ./abides-core \
 && pip install --no-cache-dir -e ./abides-markets \
 && pip install --no-cache-dir -e ./abides-gym

# Copy the rest of the tree (notebooks, tests, tools, etc.).
# The bind-mount at runtime will overlay this anyway, but copying makes the
# image self-contained when run without a mount.
COPY . .

# Directory for student notebooks / output (typically bind-mounted).
RUN mkdir -p /abides/student_work \
 && chown -R ${USER_UID}:${USER_GID} /abides

USER ${USERNAME}

EXPOSE 8888

# JupyterLab on 8888. JUPYTER_TOKEN is empty by default for class convenience;
# set it in compose / shell env if you ever expose the port beyond localhost.
ENV JUPYTER_TOKEN=""
CMD ["sh", "-c", "jupyter lab \
        --ip=0.0.0.0 \
        --port=8888 \
        --no-browser \
        --notebook-dir=/abides \
        --ServerApp.token=${JUPYTER_TOKEN} \
        --ServerApp.password="]
