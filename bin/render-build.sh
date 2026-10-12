#!/usr/bin/env bash
# Build step for Render. Exits on the first failure so a broken deploy does not
# go live half-finished.
set -o errexit

bundle install
bundle exec rails assets:precompile
bundle exec rails assets:clean

# db:prepare rather than db:migrate.
#
# On an empty database db:migrate loads schema.rb and then records the
# migrations; if that is interrupted the tables exist but schema_migrations does
# not, and every later deploy fails with "type ... already exists" -- which is
# exactly what happened on the first attempt here. db:prepare handles both the
# empty and the already-migrated case and is what Rails recommends on deploy.
#
# Seeding is NOT run here: the photographs are not in git, so the server cannot
# seed them. See docs/deployment.md.
bundle exec rails db:prepare
