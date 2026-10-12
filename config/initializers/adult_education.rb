# The parish's adult education class.
#
# The playlist is public, so its id is not a secret.
Rails.application.config.adult_education = ActiveSupport::OrderedOptions.new.tap do |c|
  c.playlist_id  = ENV.fetch("ADULT_EDUCATION_PLAYLIST", "PLQsSPU5CSGtY")
  c.playlist_url = "https://www.youtube.com/playlist?list=#{c.playlist_id}"
end
