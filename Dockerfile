FROM rocker/rstudio:3.4.4

RUN apt-get update -qq && apt-get -y --no-install-recommends install \
  libxml2-dev \
  libcairo2-dev \
  libsqlite3-dev \
  libmariadbd-dev \
  libmariadb-client-lgpl-dev \
  libpq-dev \
  libssh2-1-dev \
  unixodbc-dev \
  && install2.r --error \
    --deps TRUE \
    tidyverse \
    dplyr \
    ggplot2 \
    devtools \
    formatR \
    remotes \
    selectr \
    caTools

ENV WORKON_HOME /opt/virtualenvs
ENV PYTHON_VENV_PATH $WORKON_HOME/r-tensorflow

## Set up a user modifyable python3 environment
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        libpython3-dev \
        python3-venv \
		unixodbc \
		unixodbc-dev \
		freetds-dev \
		tdsodbc \
		odbc-postgresql && \
    rm -rf /var/lib/apt/lists/*

## Add LaTeX, rticles and bookdown support
## Add binaries for more CRAN packages, deb-src repositories in case we need `apt-get build-dep`
RUN echo 'deb http://debian-r.debian.net/debian-r/ unstable main' >> /etc/apt/sources.list \
  && gpg --keyserver keyserver.ubuntu.com --recv-keys AE05705B842492A68F75D64E01BF7284B26DD379 \
  && gpg --export AE05705B842492A68F75D64E01BF7284B26DD379  | apt-key add - \
  && echo 'deb-src http://debian-r.debian.net/debian-r/ unstable main' >> /etc/apt/sources.list \
  && echo 'deb-src http://http.debian.net/debian testing main' >> /etc/apt/sources.list

## LaTeX:
## This installs inconsolata fonts used in R vignettes/manuals manually since texlive-fonts-extra is HUGE

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    aspell \
    aspell-en \
    ghostscript \
    imagemagick \
    lmodern \
    texlive-fonts-recommended \
    texlive-humanities \
    texlive-latex-extra \
    texinfo \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/ \
  && cd /usr/share/texlive/texmf-dist \
  && wget http://mirrors.ctan.org/install/fonts/inconsolata.tds.zip \
  && unzip inconsolata.tds.zip \
  && rm inconsolata.tds.zip \
  && echo "Map zi4.map" >> /usr/share/texlive/texmf-dist/web2c/updmap.cfg \
  && mktexlsr \
  && updmap-sys

## Install some external dependencies. 360 MB
RUN apt-get update \
  && apt-get install -y --no-install-recommends -t unstable \
    build-essential \
    default-jdk \
    default-jre \
    libcairo2-dev \
    libssl-dev \
    libgsl0-dev \
    libmysqlclient-dev \
    libpq-dev \
    libsqlite3-dev \
    libv8-dev \
    libxcb1-dev \
    libxdmcp-dev \
    libxml2-dev \
    libxslt1-dev \
    libxt-dev \
    r-cran-rgl \
    r-cran-rsqlite.extfuns \
    vim \
  && R CMD javareconf \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/ \
  && rm -rf /tmp/downloaded_packages/ /tmp/*.rds \
  ## And some nice R packages for publishing-related stuff
  && install2.r --error --deps TRUE \
    bookdown rticles rmdshower rJava    
	
RUN R -e "install.packages(c('odbc', 'RPostgreSQL', 'RODBC'), dependencies=TRUE, repos='http://cran.rstudio.com/')"
RUN R -e "remove.packages('scales')"
RUN R -e "devtools::install_github('cwickham/munsell')"
RUN R -e "devtools::install_github('r-lib/scales')"
RUN R -e "devtools::install_github('moodysanalytics/RCfun', auth_token = '28c0419bf4c6e7f621c963b2c2f1d33d7bfcdcac')"

RUN python3 -m venv ${PYTHON_VENV_PATH}

RUN chown -R rstudio:rstudio ${WORKON_HOME}
ENV PATH ${PYTHON_VENV_PATH}/bin:${PATH}
## And set ENV for R! It doesn't read from the environment...
RUN echo "PATH=${PATH}" >> /usr/local/lib/R/etc/Renviron && \
    echo "WORKON_HOME=${WORKON_HOME}" >> /usr/local/lib/R/etc/Renviron && \
    echo "RETICULATE_PYTHON_ENV=${PYTHON_VENV_PATH}" >> /usr/local/lib/R/etc/Renviron

## Because reticulate hardwires these PATHs...
RUN ln -s ${PYTHON_VENV_PATH}/bin/pip /usr/local/bin/pip && \
    ln -s ${PYTHON_VENV_PATH}/bin/virtualenv /usr/local/bin/virtualenv

## install as user to avoid venv issues later
USER rstudio
RUN pip3 install \
    h5py==2.9.0 \
    pyyaml==3.13 \
    requests==2.21.0 \
    Pillow==5.4.1 \
    tensorflow==1.12.0 \
    tensorflow-probability==0.5.0 \
    keras==2.2.4 \
    --no-cache-dir
USER root
RUN install2.r reticulate tensorflow keras

## Not clear why tensorflow::install_tensorflow() fails (cant find /usr/local/bin/virtualenv). 
## keras::install_keras() cannot specify a custom envname

## Not clear how we control versions...
#RUN R -e "reticulate::py_install(c( \
#  'tensorflow', \ 
#  'tensorflow-probability', \
#  'keras'))"

###RUN R -e "tensorflow::install_tensorflow(version='cpu', extra_packages = c('keras'), envname='r-tensorflow')"

# https://hub.docker.com/r/rocker/ml/dockerfile
# Python Xgboost for CPU
USER rstudio
RUN pip3 --no-cache-dir install \
    xgboost==0.81 \
    wheel==0.33.0 \
    setuptools==40.8.0 \
    scipy==1.2.1
USER root

## Get Java (for h2o R package)
RUN apt-get update -qq \
  && apt-get -y --no-install-recommends install \
    cmake \
    default-jdk \
    default-jre \
  && R CMD javareconf

## h2o requires Java
RUN install2.r h2o
#RUN install2.r greta
RUN installGithub.r greta-dev/greta
