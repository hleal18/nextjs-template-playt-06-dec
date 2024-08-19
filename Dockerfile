ARG RUBY_VERSION=3.1.5
FROM registry.docker.com/library/ruby:$RUBY_VERSION-slim as base
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential curl git libpq-dev node-gyp pkg-config python-is-python3

FROM node:16-alpine AS builder
WORKDIR /app
COPY package.json package.json
RUN yarn install
COPY . .
RUN yarn build && yarn --production
#Hello
FROM node:16-alpine
WORKDIR /app
# RUN apt-get update -qq && \
#     apt-get install --no-install-recommends -y wkhtmltopdf ttf-mscorefonts-installer curl tmux postgresql-client jq 
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/public ./public
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/next.config.js ./next.config.js

EXPOSE 3000
CMD ["node_modules/.bin/next", "start"]
