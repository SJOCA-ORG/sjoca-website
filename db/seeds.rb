# What a database arrives with.
#
# The order below is the order of the new world. A deployment gets the SAMPLE
# SITES and nothing else: no customer, no parish, no data anybody has to be
# trusted with. Organizations arrive afterwards -- created in the operator
# console from a starter, or imported from an archive they brought with them.
#
#   bin/rails db:seed              the looks, and in development two test sites
#   SEED_SJOCA=1 bin/rails db:seed  also this parish, from the old seed files
#
# The parish content below is one organization's website that happens to live
# in this repository for historical reasons -- it is how the site was built
# before any of this was multi-organization. It is on its way out: once the
# parish is deployed and taking its own archives, those three files go, and
# docs/organizations.md says where its content lives instead.
puts "Starters:"
load Rails.root.join("db/seeds/starters.rb")

puts "Test organizations:"
load Rails.root.join("db/seeds/test_organizations.rb")

if ENV["SEED_SJOCA"].present?
  puts "This parish (SEED_SJOCA is set):"
  load Rails.root.join("db/seeds/photos.rb")
  load Rails.root.join("db/seeds/content.rb")
  load Rails.root.join("db/seeds/curated_assets.rb")
end
