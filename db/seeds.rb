# Seeds run in order: assets first, then the content that references them.
#
#   bin/rails db:seed                      # normal; existing pages left alone
#   FORCE_CONTENT_RESEED=1 bin/rails db:seed   # re-import the old site's content
#
# Images come from a local capture -- see db/seeds/legacy_assets.rb for why they
# are not in git and how the first production seed is run.
load Rails.root.join("db/seeds/legacy_assets.rb")
load Rails.root.join("db/seeds/content.rb")
load Rails.root.join("db/seeds/curated_assets.rb")
load Rails.root.join("db/seeds/demo_calendar.rb")
