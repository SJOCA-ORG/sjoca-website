class LectionaryDrop < BaseDrop
  def today
    day = LectionaryDay.today
    day && DayDrop.new(day)
  end

  # How many days ahead to show belongs to the template:
  #   {% for day in site.lectionary.ahead limit: 6 %}
  CAP_DAYS = 30

  def ahead
    @ahead ||= LectionaryDay.where(on: Date.current.tomorrow..(Date.current + CAP_DAYS))
                            .order(:on).map { |d| DayDrop.new(d) }
  end

  def has_ahead = ahead.any?

  # Chosen by day of the year, so it changes daily, everyone sees the same one,
  # and it is stable across a reload.
  def icon
    names = Photo.published.where("human_name LIKE 'icon-of-the-day-%'")
                 .distinct.order(:human_name).pluck(:human_name)
    return nil if names.empty?

    photo = Photo.newest(names[Date.current.yday % names.size])
    photo && PhotoDrop.new(photo)
  end

  class DayDrop < BaseDrop
    def initialize(day) = @day = day

    def date_text      = @day.date_text
    def day_name       = @day.on.strftime("%A")
    def commemorations = @day.commemorations
    def appointed      = @day.appointed.map { |r| ReadingDrop.new(r) }
    def citations      = @day.appointed.map(&:citation).join(" · ")
  end

  class ReadingDrop < BaseDrop
    def initialize(reading) = @r = reading

    def kind       = @r.kind
    def citation   = @r.citation
    def body       = @r.body
    def has_body   = @r.body.present?
    def verses     = @r.verses.map { |num, text| { "number" => num, "text" => text } }
    def paragraphs = @r.paragraphs
  end
end
