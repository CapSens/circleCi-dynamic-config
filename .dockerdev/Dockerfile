# syntax=docker/dockerfile:1

ARG RUBY_VERSION
ARG DISTRO_NAME=bullseye

FROM ruby:$RUBY_VERSION-slim-$DISTRO_NAME AS base
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
  apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  build-essential \
  gnupg2 \
  curl \
  less \
  git \
  libjemalloc2 \
  xz-utils \
  shared-mime-info

# Install postgres
ARG PG_MAJOR
RUN curl -sSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /usr/share/keyrings/postgres-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/postgres-archive-keyring.gpg] https://apt.postgresql.org/pub/repos/apt/" \
  $DISTRO_NAME-pgdg main $PG_MAJOR | tee /etc/apt/sources.list.d/postgres.list > /dev/null
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=tmpfs,target=/var/log \
  apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  libpq-dev \
  postgresql-client-$PG_MAJOR

# Install NodeJS and NPM from Nodesource
ARG NODE_MAJOR=21
RUN echo "Package: nodejs" >> /etc/apt/preferences.d/preferences \
  && echo "Pin: origin deb.nodesource.com" >> /etc/apt/preferences.d/preferences \
  && echo "Pin-Priority: 1001" >> /etc/apt/preferences.d/preferences

RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && npm install -g yarn

ARG PACKAGES_TO_INSTALL=""
COPY .dockerdev/Aptfile /tmp/Aptfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=tmpfs,target=/var/log \
  apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  $(echo $(grep -Ev '^\s*#' /tmp/Aptfile | xargs) $PACKAGES_TO_INSTALL | xargs -n1 | sort -u | xargs)

ARG PIP_PACKAGES=""
RUN if test -n "$PIP_PACKAGES" ; \
  then \
    # create symlink to python3 and pip3 if not exists
    ln -s /usr/bin/python3 /usr/bin/python && (ln -s /usr/bin/pip3 /usr/bin/pip || echo "file exist") \
    # add  --break-system-packages option to pip install to use it in a virtual env
    && pip install --no-cache-dir $PIP_PACKAGES; \
  fi ;

# Configure bundler
ENV LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3 \
  LD_PRELOAD=libjemalloc.so.2

# Store Bundler settings in the project's root
ENV BUNDLE_APP_CONFIG=.bundle

# Uncomment this line if you want to run binstubs without prefixing with `bin/` or `bundle exec`
# ENV PATH /app/bin:$PATH

# Upgrade RubyGems if possible
RUN if echo -e "3.1\n$RUBY_VERSION" | sort -V -C ; \
  then \
    gem update --system --no-document; \
  elif echo -e "2.7\n$RUBY_VERSION" | sort -V -C ; \
  then \
    gem update --system 3.4.22 --no-document; \
  fi ;

# Create a directory for the app code
RUN mkdir -p /app
WORKDIR /app

# Document that we're going to expose port 3000
EXPOSE 3000
# Use Bash as the default command
CMD ["/usr/bin/bash"]

##################
### Production ###
##################

# The production-builder image is responsible for installing dependencies and compiling assets
FROM base AS production-builder

# First, we create and configure a dedicated user to run our application
RUN groupadd --gid 1005 my_user \
  && useradd --uid 1005 --gid my_user --shell /bin/bash --create-home my_user
USER my_user
RUN mkdir /home/my_user/app
WORKDIR /home/my_user/app

ARG RAILS_ENV
ARG GITHUB_TOKEN

# Then, we re-configure Bundler
ENV RAILS_ENV=$RAILS_ENV \
  NODE_ENV=production \
  LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3 \
  BUNDLE_APP_CONFIG=/home/my_user/bundle \
  BUNDLE_PATH=/home/my_user/bundle \
  GEM_HOME=/home/my_user/bundle \
  BUNDLE_GITHUB__COM=x-access-token:"$GITHUB_TOKEN" \
  LD_PRELOAD=libjemalloc.so.2

# Copy code
COPY --chown=my_user:my_user . .

RUN mkdir $BUNDLE_PATH \
  && sed -i 's/git@github.com:/https:\/\/github.com\//g' Gemfile Gemfile.lock \
  && sed -i '/letter_opener_web/s/.*/  gem "letter_opener_web", git: "https:\/\/github.com\/CapSens\/letter_opener_web.git", branch: "master"/' Gemfile \
  && bundle lock \
  && bundle config --local path "${BUNDLE_PATH}" \
  && bundle config set clean "true" \
  && bundle config set no-cache "true" \
  && bundle config --local without "development:test" \
  && bundle lock --add-platform x86_64-linux \
  && bundle install --jobs=${BUNDLE_JOBS} \
  && rm -rf $BUNDLE_PATH/ruby/*/cache/* \
  && rm -rf /home/my_user/.bundle/cache/*

# Install JS packages
RUN yarn install --check-files

ARG DB_ADAPTER=postgresql
ENV DB_NAME=fake_database_name
ENV DB_ADAPTER=$DB_ADAPTER
# Copy database config to avoid human errors
COPY --chown=my_user:my_user .dockerdev/database.yml.template /home/my_user/app/config/database.yml

# Precompile assets
# NOTE: The app may require some environment variables (e.g., SECRET_KEY_BASE). All known mandatory variables
# are listed with fake values in .dockerdev/env_variables.sh script and exported below
RUN ( \
  source .dockerdev/.env \
  && env \
  && env_file_name=./config/environments/${RAILS_ENV}.rb \
  && echo 'Rails.application.config.require_master_key = false' >> $env_file_name \
  && bundle exec rake assets:clobber assets:precompile \
  && sed -i '$ d' $env_file_name \
)

# Finally, our production image definition
# NOTE: It's not extending the base image, it's a new one
FROM ruby:$RUBY_VERSION-slim-$DISTRO_NAME AS production
SHELL ["/bin/bash", "-c"]

# Production-only dependencies
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=tmpfs,target=/var/log \
  apt-get update -qq \
  && DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  build-essential \
  curl \
  gnupg2 \
  less \
  tzdata \
  time \
  locales \
  libpq5 \
  libjemalloc2 \
  file \
  shared-mime-info \
  && update-locale LANG=C.UTF-8 LC_ALL=C.UTF-8

# Install NodeJS and NPM from Nodesource
ARG NODE_MAJOR=21
ARG FORCE_NODE=""
RUN echo "Package: nodejs" >> /etc/apt/preferences.d/preferences && \
    echo "Pin: origin deb.nodesource.com" >> /etc/apt/preferences.d/preferences && \
    echo "Pin-Priority: 1001" >> /etc/apt/preferences.d/preferences

RUN test -n "$FORCE_NODE" \
  && curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && npm install -g yarn \
  || echo "nodejs not mandatory for production environment"

ARG PACKAGES_TO_INSTALL=""
COPY .dockerdev/Aptfile /tmp/Aptfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=tmpfs,target=/var/log \
  apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  $(echo $(grep -Ev '^\s*#' /tmp/Aptfile | xargs) $PACKAGES_TO_INSTALL | xargs -n1 | sort -u | xargs)

ARG PIP_PACKAGES=""
RUN if test -n "$PIP_PACKAGES" ; \
  then \
    # create symlink to python3 and pip3 if not exists
    ln -s /usr/bin/python3 /usr/bin/python && (ln -s /usr/bin/pip3 /usr/bin/pip || echo "file exist") \
    # add  --break-system-packages option to pip install to use it in a virtual env
    && pip install --no-cache-dir $PIP_PACKAGES; \
  fi ;

# add policy to allow convert images to PDF with imagemagick if it's installed
RUN if command -v convert &> /dev/null; \
  then \
    policy_path='/etc/ImageMagick-*/policy.xml'; \
    old_line_regex='rights="none" pattern="PDF"'; \
    new_policy='rights="read|write" pattern="PDF"'; \
    sed -i "s/$old_line_regex/$new_policy/" $policy_path; \
  else \
    echo "imagemagick not mandatory for production environment"; \
  fi

# Upgrade RubyGems if possible
RUN if echo -e "3.1\n$RUBY_VERSION" | sort -V -C ; \
  then \
    gem update --system --no-document; \
  elif echo -e "2.7\n$RUBY_VERSION" | sort -V -C ; \
  then \
    gem update --system 3.4.22 --no-document; \
  fi ;

# Create and configure a dedicated user (use the same name as for the production-builder image)
RUN groupadd --gid 1005 my_user \
  && useradd --uid 1005 --gid my_user --shell /bin/bash --create-home my_user
RUN mkdir /home/my_user/app
WORKDIR /home/my_user/app
USER my_user

ARG RAILS_ENV
# Ruby/Rails env configuration
ENV RAILS_ENV=$RAILS_ENV \
  BUNDLE_APP_CONFIG=/home/my_user/bundle \
  BUNDLE_PATH=/home/my_user/bundle \
  GEM_HOME=/home/my_user/bundle \
  PATH="/home/my_user/app/bin:${PATH}" \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 \
  LD_PRELOAD=libjemalloc.so.2 \
  MALLOC_CONF=narenas:2

EXPOSE 3000

# Copy code
COPY --chown=my_user:my_user . .

# Configure Rails to allow public file server served by app server
RUN sed -i 's/\(.*public_file_server\.enabled.*= \).*/\1true/' config/environments/${RAILS_ENV}.rb

# Copy database config to avoid human errors
COPY --chown=my_user:my_user .dockerdev/database.yml.template /home/my_user/app/config/database.yml
# Copy letter_opener config to use it with S3
COPY --chown=my_user:my_user .dockerdev/letter_opener_config.rb /home/my_user/app/config/initializers/letter_opener.rb

# Copy artifacts
# 1) Installed gems
COPY --chown=my_user:my_user --from=production-builder $BUNDLE_PATH $BUNDLE_PATH
# 1bis) Gemfile.lock updated with platform x86_64-linux
COPY --chown=my_user:my_user --from=production-builder /home/my_user/app/Gemfile* /home/my_user/app/
# 2) Compiled assets
COPY --from=production-builder /home/my_user/app/public/asset[s]/ /home/my_user/app/public/assets
# pack[s] is on purpose. Using glob pattern to avoid error if folder does not exists
COPY --from=production-builder /home/my_user/app/public/pack[s]/ /home/my_user/app/public/packs
# 3) We can even copy the Bootsnap cache to speed up our Rails server load!
COPY --chown=my_user:my_user --from=production-builder /home/my_user/app/tmp/cach[e]/bootsnap* /home/my_user/app/tmp/cache/

# Install bundler version used in Gemfile.lock
RUN gem install bundler -v "$(grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1)"

# Force creation of tmp and log folders if not exists
RUN mkdir -p /home/my_user/app/tmp /home/my_user/app/log

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
