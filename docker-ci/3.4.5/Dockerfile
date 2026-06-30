FROM ruby:3.4.5-bullseye AS base
SHELL ["/bin/bash", "-c"]

RUN echo "IRB.conf[:HISTORY_FILE] = ENV['IRB_HISTFILE']" >> ~/.irbrc

ARG DISTRO_NAME

# Common dependencies
# Using --mount to speed up build with caching, see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md#run---mount
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=tmpfs,target=/var/log \
  rm -f /etc/apt/apt.conf.d/docker-clean; \
  echo 'Binary::apt::APT::Keep-Downloaded-Packages "true";' > /etc/apt/apt.conf.d/keep-cache; \
  apt-get update --allow-releaseinfo-change -qq --fix-missing && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  build-essential \
  postgresql-client \
  curl \
  libjemalloc2 \
  libpq-dev \
  xz-utils \
  vim \
  shared-mime-info \
  pdftk \
  imagemagick \
  libyaml-dev \
  python3-pip \
  software-properties-common \
  && apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/* /var/lib/apt/* /tmp/* /var/tmp/*

RUN pip3 install --upgrade pip \
  && pip3 install "awscli<1.36.0"

# Install NodeJS and NPM from Nodesource
ARG NODE_MAJOR=21
RUN echo "Package: nodejs" >> /etc/apt/preferences.d/preferences \
  && echo "Pin: origin deb.nodesource.com" >> /etc/apt/preferences.d/preferences \
  && echo "Pin-Priority: 1001" >> /etc/apt/preferences.d/preferences

RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && npm install -g yarn

# Configure bundler
ENV LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3 \
  LD_PRELOAD=libjemalloc.so.2

RUN sed -i 's#<policy domain="coder" rights="none" pattern="PDF" />#<policy domain="coder" rights="read|write" pattern="PDF" />#' /etc/ImageMagick-6/policy.xml
