namespace :db do
  desc "Replace the local database with a copy of the server's"
  task pull: :environment do
    # The work is in bin/pull-production-db: pg_dump and pg_restore want a
    # shell, and the script carries the warnings about what a dump contains.
    # This exists so it shows up in `rails -T` next to everything else.
    abort "refusing to run in production" if Rails.env.production?

    exec(Rails.root.join("bin/pull-production-db").to_s, *ARGV.drop(1))
  end
end
