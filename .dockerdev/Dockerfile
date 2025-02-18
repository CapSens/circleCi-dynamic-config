# syntax=docker/dockerfile:1

ARG RUBY_VERSION
ARG DISTRO_NAME=bullseye

FROM ruby:$RUBY_VERSION-slim-$DISTRO_NAME AS base
SHELL ["/bin/bash", "-c"]

RUN echo "IRB.conf[:HISTORY_FILE] = ENV['IRB_HISTFILE']" >> ~/.irbrc

ARG DISTRO_NAME

# Common dependencies
# Using --mount to speed up build with caching, see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md#run---mount
ARG PACKAGES_TO_INSTALL=""
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=tmpfs,target=/var/log \
  rm -f /etc/apt/apt.conf.d/docker-clean; \
  apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  less \
  libjemalloc2 \
  shared-mime-info \
  libpq5 \
  file \
  $(echo $PACKAGES_TO_INSTALL | xargs -n1 | sort -u | xargs) \
  && rm -rf /var/lib/apt/lists/*

ARG PIP_PACKAGES=""
RUN if test -n "$PIP_PACKAGES" ; \
  then \
    # create symlink to python3 and pip3 if not exists
    ln -s /usr/bin/python3 /usr/bin/python && (ln -s /usr/bin/pip3 /usr/bin/pip || echo "file exist") \
    # add  --break-system-packages option to pip install to use it in a virtual env
    && pip install --no-cache-dir $PIP_PACKAGES; \
  fi ;

# Upgrade RubyGems if possible
RUN if echo -e "3.1\n$RUBY_VERSION" | sort -V -C ; \
  then \
    gem update --system --no-document; \
  elif echo -e "2.7\n$RUBY_VERSION" | sort -V -C ; \
  then \
    gem update --system 3.4.22 --no-document; \
  fi ;

ARG RAILS_ENV
# Ruby/Rails env configuration
ENV RAILS_ENV=$RAILS_ENV \
  NODE_ENV=production \
  BUNDLE_APP_CONFIG=/usr/local/bundle \
  BUNDLE_PATH=/usr/local/bundle \
  GEM_HOME=/usr/local/bundle \
  PATH="/home/my_user/app/bin:${PATH}" \
  LANG=C.UTF-8 \
  LC_ALL=C.UTF-8 \
  LD_PRELOAD=libjemalloc.so.2 \
  MALLOC_CONF=narenas:2 \
  BUNDLE_WITHOUT="development test"

FROM base AS production-builder

# Rails app lives here
WORKDIR /rails

# buildr dependencies
# Using --mount to speed up build with caching, see https://github.com/moby/buildkit/blob/master/frontend/dockerfile/docs/reference.md#run---mount
ARG PACKAGES_TO_INSTALL=""
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
  --mount=type=cache,target=/var/lib/apt,sharing=locked \
  --mount=type=tmpfs,target=/var/log \
  rm -f /etc/apt/apt.conf.d/docker-clean; \
  apt-get update -qq && \
  DEBIAN_FRONTEND=noninteractive apt-get install -yq --no-install-recommends \
  build-essential \
  git \
  wget \
  libpq-dev \
  && rm -rf /var/lib/apt/lists/*

# Install NodeJS and NPM from Nodesource
ARG NODE_MAJOR=21
RUN echo "Package: nodejs" >> /etc/apt/preferences.d/preferences \
  && echo "Pin: origin deb.nodesource.com" >> /etc/apt/preferences.d/preferences \
  && echo "Pin-Priority: 1001" >> /etc/apt/preferences.d/preferences \
  && wget -qO- https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/* \
  && npm install -g yarn

ARG GITHUB_TOKEN
# Then, we re-configure Bundler
ENV RAILS_ENV=$RAILS_ENV \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3 \
  BUNDLE_GITHUB__COM=x-access-token:"$GITHUB_TOKEN"

# Copy code
COPY Gemfile Gemfile.lock ./

# Install bundler version used in Gemfile.lock
RUN gem install bundler -v "$(grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1)"

RUN mkdir -p $BUNDLE_PATH \
  && sed -i 's/git@github.com:/https:\/\/github.com\//g' Gemfile Gemfile.lock \
  # && sed -i '/letter_opener_web/s/.*/  gem "letter_opener_web", git: "https:\/\/github.com\/CapSens\/letter_opener_web.git", branch: "master"/' Gemfile \
  && bundle lock \
  && bundle config --local path "${BUNDLE_PATH}" \
  && bundle config set clean "true" \
  && bundle config set no-cache "true" \
  && bundle config --local without "development:test" \
  && bundle lock --add-platform x86_64-linux \
  && bundle install --jobs=${BUNDLE_JOBS} \
  && rm -rf $BUNDLE_PATH/.bundle $BUNDLE_PATH/ruby/*/cache/* $BUNDLE_PATH/ruby/*/bundler/gems/*/.git \
  && bundle exec bootsnap precompile --gemfile

# Copy application code
COPY . .

#Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

ARG DB_ADAPTER=postgresql
ENV DB_NAME=fake_database_name
ENV DB_ADAPTER=$DB_ADAPTER
# Copy database config to avoid human errors
COPY --chown=my_user:my_user .dockerdev/database.yml.template /home/my_user/app/config/database.yml

# Install JS packages
RUN yarn install --check-files

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
FROM base AS production
SHELL ["/bin/bash", "-c"]
WORKDIR "/home/my_user/app"

# Install NodeJS and NPM from Nodesource
ARG NODE_MAJOR=21
ARG FORCE_NODE=""
RUN test -n "$FORCE_NODE" \
  && echo "Package: nodejs" >> /etc/apt/preferences.d/preferences \
  && echo "Pin: origin deb.nodesource.com" >> /etc/apt/preferences.d/preferences \
  && echo "Pin-Priority: 1001" >> /etc/apt/preferences.d/preferences \
  && wget -qO- https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/* \
  && npm install -g yarn \
  || echo "nodejs not mandatory for production environment"

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

# Copy code
COPY . .

# Configure Rails to allow public file server served by app server
RUN sed -i 's/\(.*public_file_server\.enabled.*= \).*/\1true/' config/environments/${RAILS_ENV}.rb

# Copy database config to avoid human errors
COPY .dockerdev/database.yml.template /home/my_user/app/config/database.yml
# Copy letter_opener config to use it with S3
COPY .dockerdev/letter_opener_config.rb /home/my_user/app/config/initializers/letter_opener.rb

# Copy artifacts
# 1) Installed gems
COPY --from=production-builder $BUNDLE_PATH $BUNDLE_PATH
# 1bis) Gemfile.lock updated with platform x86_64-linux
COPY --from=production-builder /rails/Gemfile* /home/my_user/app/
# 2) Compiled assets
COPY --from=production-builder /rails/public/asset[s]/ /home/my_user/app/public/assets
# pack[s] is on purpose. Using glob pattern to avoid error if folder does not exists
COPY --from=production-builder /rails/public/pack[s]/ /home/my_user/app/public/packs
# 3) We can even copy the Bootsnap cache to speed up our Rails server load!
COPY --from=production-builder /rails/tmp/cach[e]/bootsnap* /home/my_user/app/tmp/cache/

# Install bundler version used in Gemfile.lock
RUN gem install bundler -v "$(grep -A 1 'BUNDLED WITH' Gemfile.lock | tail -n 1)"

# Force creation of tmp and log folders if not exists
RUN mkdir -p /home/my_user/app/tmp /home/my_user/app/log

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 my_user && \
    useradd my_user --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R my_user:my_user /home/my_user
USER 1000:1000

EXPOSE 3000
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
