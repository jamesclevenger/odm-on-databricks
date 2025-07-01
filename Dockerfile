#####################################
### Based on Docker file in https://github.com/OpenDroneMap/ODM
### modfied to include packages needed to run as Databricks node
##################################
FROM ubuntu:21.04 AS builder

# Env variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONPATH="$PYTHONPATH:/code/SuperBuild/install/lib/python3.9/dist-packages:/code/SuperBuild/install/lib/python3.8/dist-packages:/code/SuperBuild/install/bin/opensfm"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/code/SuperBuild/install/lib"

# Prepare directories
WORKDIR /code

# Copy everything
COPY ../ODM ./

# Use old-releases for 21.04
RUN printf "deb http://old-releases.ubuntu.com/ubuntu/ hirsute main restricted\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates main restricted\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute universe\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates universe\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute multiverse\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates multiverse\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-backports main restricted universe multiverse" > /etc/apt/sources.list

# Run the build
RUN bash configure.sh install

# Clean Superbuild
RUN bash configure.sh clean

### END Builder

### Use a second image for the final asset to reduce the number and
# size of the layers.
FROM ubuntu:21.04

# Env variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONPATH="$PYTHONPATH:/code/SuperBuild/install/lib/python3.9:/code/SuperBuild/install/lib/python3.8/dist-packages:/code/SuperBuild/install/bin/opensfm"
ENV LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/code/SuperBuild/install/lib"
ENV PDAL_DRIVER_PATH="/code/SuperBuild/install/bin"
ENV DATABRICKS_RUNTIME_VERSION=13.3
ENV USER=root

WORKDIR /code

# Copy everything we built from the builder
COPY --from=builder /code /code

# Copy the Python libraries installed via pip from the builder
COPY --from=builder /usr/local /usr/local

# Use old-releases for 21.04
RUN printf "deb http://old-releases.ubuntu.com/ubuntu/ hirsute main restricted\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates main restricted\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute universe\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates universe\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute multiverse\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-updates multiverse\ndeb http://old-releases.ubuntu.com/ubuntu/ hirsute-backports main restricted universe multiverse" > /etc/apt/sources.list

RUN apt-get update \
    # first we install some required packages on the Ubuntu base image
    && apt-get -y upgrade \
    && apt-get install --yes \
    openjdk-8-jdk \
    iproute2 \
    bash \
    sudo \
    coreutils \
    procps \
    curl \
    fuse \
    gcc \
    software-properties-common \
    #python3.10 \
    #python3.10-dev \
    #python3.10-distutils \
    python3.9 \
    python3.9-dev \
    python3.9-distutils \
    && /var/lib/dpkg/info/ca-certificates-java.postinst configure \
    # install pip so we can install some python packages
    && curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py \
    #&& /usr/bin/python3.10 get-pip.py pip==22.2.2 setuptools==63.4.1 wheel==0.37.1 \
    && /usr/bin/python3.9 get-pip.py pip==22.2.2 setuptools==63.4.1 wheel==0.37.1 \
    && rm get-pip.py \
    # # install poetry
    # && curl -fLSs https://install.python-poetry.org -o $HOME/get-poetry.py \
    # && python3.10 $HOME/get-poetry.py --yes \
    # # set poetry in path
    # && export PATH="$HOME/.local/bin:$PATH" \
    # # workaround for PEP440 bug https://bugs.launchpad.net/ubuntu/+source/python-debian/+bug/1926870
    # && pip uninstall -y distro-info \
    # && poetry config virtualenvs.create false \
    # get virtualenv
    #&& /usr/local/bin/pip3.10 install --no-cache-dir virtualenv==20.24.2 \
    && /usr/local/bin/pip3.9 install --no-cache-dir virtualenv==20.24.2 \
    # create a virtualenv for python3.10 note the /databricks/python3 file path this is where Databricks looks for the virtualenv
    && virtualenv --python=python3.9 --system-site-packages /databricks/python3 --no-download  --no-setuptools \
    # install some default packages needed, that are required by the cluster.
    && /databricks/python3/bin/pip install \
     six==1.16.0 \
     jedi==0.18.1 \
    # ensure minimum ipython version for Python autocomplete with jedi 0.17.x
     ipython==8.10.0 \
     numpy==1.21.5 \
     pandas==1.4.4 \
     pyarrow==8.0.0 \
     matplotlib==3.5.2 \
     jinja2==2.11.3 \
     ipykernel==6.17.1 \
     databricks-connect==13.2.0 \
     black==22.6.0 \
     tokenize-rt==4.2.1 \
    && apt-get purge --auto-remove --yes \
     python3-virtualenv \
     virtualenv \
     file \
     gnupg2  \
     libtool

WORKDIR /code

# Install shared libraries that we depend on via APT, but *not*
# the -dev packages to save space!
# Also run a smoke test on ODM and OpenSfM
RUN bash configure.sh installruntimedepsonly \
  && export PATH="$HOME/.local/bin:$PATH" \
  && apt-get clean \
  && apt-get remove -y gcc  \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
  && bash run.sh --help \
  && bash -c "eval $(python3 /code/opendm/context.py) && python3 -c 'from opensfm import io, pymap'"

  # Entry point
#ENTRYPOINT ["python3", "/code/run.py"]


