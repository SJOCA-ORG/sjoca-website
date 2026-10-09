module ApplicationHelper
  # Content came out of the old site's HTML, so it carries a little inline
  # markup. Allow only what we deliberately extracted and nothing else —
  # once parishioners can edit this text in Phase 2, it is user input.
  INLINE_TAGS  = %w[a br strong em].freeze
  INLINE_ATTRS = %w[href].freeze

  def sanitize_inline(html)
    sanitize(html.to_s, tags: INLINE_TAGS, attributes: INLINE_ATTRS)
  end
end
