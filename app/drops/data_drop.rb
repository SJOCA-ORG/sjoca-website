# site.data -- outside data, by the name whoever set it up gave it.
#
#   {{ site.data.calendar.json_tag }}
#   {{ site.data["daily-readings"].json_tag }}
#
# That writes a <script type="application/json"> element into the page. The
# site's own JavaScript then reads it and does whatever the parish wants with
# it:
#
#   const events = JSON.parse(document.getElementById("data-calendar").textContent);
#
# This is deliberately the ONLY thing this drop does. It does not group, filter,
# sort, or decide what is worth showing, because every one of those is an
# editorial decision that belongs in the open -- in JavaScript the AI writes and
# can read back -- rather than buried in Ruby where nothing can see it. The
# version of this file that knew what "upcoming events" meant quietly dropped
# every regularly scheduled service, and the AI built a page on top of it
# without ever being able to find out.
class DataDrop < BaseDrop
  def initialize(revision) = @revision = revision

  def available = sources.map(&:name).sort

  def liquid_method_missing(name)
    wanted = name.to_s
    source = sources.find { |s| s.name == wanted || s.name == wanted.tr("_", "-") }
    return SourceDrop.new(source) if source

    super
  end

  private

  def sources = @sources ||= @revision ? @revision.data_sources.to_a : []

  class SourceDrop < BaseDrop
    def initialize(source) = @source = source

    def name = @source.name
    def id   = "data-#{@source.name}"
    def note = @source.note.presence
    def urls = @source.url_list

    # The payload as a <script type="application/json"> element, which is the
    # normal way to hand data to a page. Not an inline variable assignment: that
    # would put attacker-influenced text into executable position, and a JSON
    # island is inert until something chooses to parse it.
    def json_tag
      "<script type=\"application/json\" id=\"#{id}\">#{escaped}</script>"
    rescue Site::OutboundFetch::Refused => e
      "<!-- #{name}: #{e.message.gsub('--', '-')} -->"
    end

    # The same payload with no wrapper, for a template that wants to put it
    # somewhere else.
    def json = escaped

    def ok      = row_states.all? { |r| r[:ok] }
    def error   = row_states.filter_map { |r| r[:error] }.first
    def stale   = row_states.any? { |r| r[:stale] }
    def age     = row_states.map { |r| r[:age] }.first
    def bytes   = row_states.sum { |r| r[:bytes] }

    private

    # JSON never contains < > or & outside a string literal, so escaping them
    # everywhere is both safe and valid JSON -- and it means a fetched page
    # containing the text "</script>" cannot close the element it sits in.
    #
    # Built from character codes rather than written as "\\u003c" literals: the
    # first version of this line lost its backslashes on the way into the file
    # and became gsub("<", "<"), a silent no-op that escaped nothing. A spec
    # caught it. Escaping is not a place to trust that a literal survived.
    ESCAPES = {
      "<" => format("%cu003c", 92),
      ">" => format("%cu003e", 92),
      "&" => format("%cu0026", 92)
    }.freeze

    def escaped = @source.payload.gsub(/[<>&]/, ESCAPES)

    def row_states
      @row_states ||= @source.pages.map do |r|
        { ok: r.error.blank?, error: r.error.presence, stale: r.stale?,
          age: r.age_text, bytes: r.body.to_s.bytesize }
      end
    rescue Site::OutboundFetch::Refused => e
      [{ ok: false, error: e.message, stale: false, age: "never fetched", bytes: 0 }]
    end
  end
end
