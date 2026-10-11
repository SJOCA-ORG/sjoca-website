# ChurchTrac's public calendar feed.
#
# `church_ui` is not a secret — it is visible in the embed on the current site —
# so it lives in config rather than credentials, with an ENV override.
Rails.application.config.church_trac = ActiveSupport::OrderedOptions.new.tap do |c|
  c.church_ui   = ENV.fetch("CHURCHTRAC_UI", "AE8E0B4D")
  c.base_url    = ENV.fetch("CHURCHTRAC_URL", "https://www.churchtrac.com")

  # How far either side of today to sync. The past is the past: we keep a month
  # behind so the current month stays whole, and never backfill further.
  c.months_back    = 1
  c.months_forward = 12
end
