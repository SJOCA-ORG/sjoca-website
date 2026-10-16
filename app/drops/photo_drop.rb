# A photograph, as a template may see it. Note what is absent: no `data`, no
# `destroy`, no way back to ActiveRecord. A template can show a photo and
# nothing else.
class PhotoDrop < BaseDrop
  def initialize(photo) = @photo = photo

  def name    = @photo.human_name
  def url     = "/media/#{@photo.human_name}/#{@photo.version}"
  def version = @photo.version
  # Escaped here, not in the template: this lands inside an attribute, and a
  # quote in the text would otherwise truncate it silently.
  def alt     = CGI.escapeHTML(@photo.alt_text.to_s)
  def width   = @photo.try(:width)
  def present = true
end
