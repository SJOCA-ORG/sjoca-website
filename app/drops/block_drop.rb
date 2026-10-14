class BlockDrop < Liquid::Drop
  def initialize(block) = @block = block

  def id      = @block.id
  def kind    = @block.kind
  # Sanitised here rather than in the template: a template author must not be
  # able to bypass it, and once the parish edits this text it is user input.
  def content = Sanitize.inline(@block.content)
  def raw_content = @block.content.to_s
  def align   = @block.align
  def width   = @block.width.presence
  def url     = @block.url.presence
  def column  = @block.column

  def photo
    asset = @block.asset
    asset && PhotoDrop.new(asset)
  end

  # Convenience for list blocks: one item per line.
  def items = @block.content.to_s.split("\n").map(&:strip).reject(&:blank?).map { |i| Sanitize.inline(i) }

  # Google Maps embeds are treated differently from videos -- click to activate.
  def map? = @block.url.to_s.include?("google.com/maps")
  alias_method :is_map, :map?
end
