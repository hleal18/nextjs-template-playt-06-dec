# syntax = docker/dockerfile:1

ARG RUBY_VERSION=3.1.5
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_SERVE_STATIC_FILES="true" \
    RAILS_LOG_TO_STDOUT="true"

# Throw-away build stage to reduce size of final image
FROM base as build

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git libpq-dev node-gyp pkg-config python-is-python3

ARG NODE_VERSION=18.18.2
ARG YARN_VERSION=latest
ENV PATH=/usr/local/node/bin:$PATH

RUN curl -sL https://github.com/nodenv/node-build/archive/master.tar.gz | tar xz -C /tmp/ && \
    /tmp/node-build-master/bin/node-build "${NODE_VERSION}" /usr/local/node && \
    npm install -g yarn@$YARN_VERSION && \
    rm -rf /tmp/node-build-master

# Install application gems
# COPY shared/pond/pond.gemspec shared/pond/
# COPY shared/az-misc/az-misc.gemspec shared/az-misc/
# COPY supplier_integrations/supplier_integrations.gemspec supplier_integrations/
# COPY front/front.gemspec front/
# COPY Gemfile Gemfile.lock ./
# COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Rails app lives here
WORKDIR /rails

# Install node modules
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile

# used by puma to store the pid file
RUN mkdir -p tmp/pids

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

FROM base

# Install packages needed for score badge generation & for deployment
RUN sed -i"" -E 's/^Components: .+$/& contrib/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y wkhtmltopdf ttf-mscorefonts-installer curl tmux postgresql-client jq && \
    ln -s /usr/bin/wkhtmltoimage /usr/local/bin/ && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# install overmind
RUN curl -sOL https://github.com/DarthSim/overmind/releases/download/v2.4.0/overmind-v2.4.0-linux-amd64.gz
RUN gunzip overmind-v2.4.0-linux-amd64.gz && chmod +x overmind-v2.4.0-linux-amd64 && mv overmind-v2.4.0-linux-amd64 /usr/local/bin/overmind

# Copy built artifacts: gems, application
COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /rails /rails
COPY --from=build /usr/local/node /usr/local/node
ENV PATH="/usr/local/node/bin:$PATH"

USER rails:rails

# Start the server by default, this can be overwritten at runtime
CMD ["./bin/rails", "server"]
