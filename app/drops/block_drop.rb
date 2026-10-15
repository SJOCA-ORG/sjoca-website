class BlockDrop < BaseDrop
  def initialize(block) = @block = block

  def id      = @block.id
  def kind    = @block.kind

  # Which template renders this block. {% include block.template %} then needs
  # no dispatcher, so adding a kind is writing ONE template.
  def template = "block/#{@block.kind}"
  # Sanitised here rather than in the template: a template author must not be
  # able to bypass it, and once the parish edits this text it is user input.
  def content = Sanitize.inline(@block.content)
  def raw_content = @block.content.to_s
  def align   = @block.align

  # An extra class for styling this one block. Bounded to safe class names so a
  # template cannot be broken by it.
  def css_class = @block.css_class.to_s.scan(/[a-z][a-z0-9_-]*/).first(3).join(" ").presence
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
