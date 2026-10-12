#!/usr/bin/env bash
# Build step for Render. Exits on the first failure so a broken deploy does not
# go live half-finished.
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean

# Schema changes are applied on every deploy. Seeding is NOT run here: the
# photographs are not in git, so the server cannot seed them. See render.yaml.
bundle exec rails db:migrate
