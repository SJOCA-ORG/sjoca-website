# Content carries a little inline markup, carried over from the old site. Allow
# only what was deliberately extracted and nothing else -- once the parish edits
# this text through the admin, it is user input.
module Sanitize
  TAGS  = %w[a br strong em].freeze
  ATTRS = %w[href].freeze

  def self.inline(html)
    ActionController::Base.helpers.sanitize(html.to_s, tags: TAGS, attributes: ATTRS)
  end
end
