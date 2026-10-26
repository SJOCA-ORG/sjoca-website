# The parish website, with everything the editor needs to actually work.
#
# Render's plain Ruby runtime has none of the programs the editor shells out to,
# so on that runtime photographs could not be uploaded, the AI could not see the
# page it had just changed, and no bulletin PDF could be made. Publishing worked
# and nothing else did.
#
# Debian 13 (trixie) matters: it ships ImageMagick 7, where the command really is
# `magick`. Debian 12 ships ImageMagick 6, where it is `convert`, and every image
# call in this app would have failed with "command not found".
ARG RUBY_VERSION=3.4.7
FROM ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_WITHOUT=development:test

# ---- build -----------------------------------------------------------------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential git libpq-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .

# Assets are built here so the running image never needs a toolchain. The key is
# a throwaway one: nothing is encrypted at this step, and baking a real one into
# an image layer would publish it.
RUN SECRET_KEY_BASE=precompile-only ./bin/rails assets:precompile

# ---- what actually runs ----------------------------------------------------
FROM base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      curl ca-certificates libpq5 postgresql-client \
      \
      # The editor's hands: every one of these is shelled out to by name.
      imagemagick ffmpeg librsvg2-bin potrace \
      \
      # gnupg is only for adding the Node repository below.
      gnupg \
      \
      # The editor's eyes. Headless Chromium drives the layout checks, the
      # screenshots the AI looks at, and bulletin printing.
      chromium \
      \
      # Without fonts a screenshot is a page of empty boxes, and a bulletin PDF
      # prints blank. Easy to forget until a PDF comes out wrong.
      fonts-liberation fonts-dejavu-core fonts-noto-color-emoji && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Node 22, not Debian's 20.
#
# script/visual_check.mjs drives Chromium over a WebSocket and uses the global
# WebSocket class deliberately, so that it needs no dependencies at all. That
# global only became available in Node 22. On Debian's Node 20 the editor's
# eyes fail with "WebSocket is not defined" -- and the failure arrives as JSON
# saying the check could not run, which is quiet enough to be missed.
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install --no-install-recommends -y nodejs && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Found by name rather than guessed at. script/visual_check.mjs already looks in
# /usr/bin, but saying so means a changed package layout fails loudly here
# instead of quietly producing a site with no eyes.
ENV CHROME=/usr/bin/chromium

# Not root. Chromium's own sandbox is already disabled in the scripts (it cannot
# work in a container without extra privileges), so the container user is the
# thing standing between a bug in an image library and the rest of the machine.
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    mkdir -p tmp log storage && \
    chown -R rails:rails /rails
USER 1000:1000

EXPOSE 3000
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
