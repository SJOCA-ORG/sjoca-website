# A log of each attempt to mirror the ChurchTrac calendar.
#
# Exists so that a sync which quietly stops working is visible. An empty
# calendar and a broken importer look identical from the front of the site.
class CalendarSync < ApplicationRecord
  scope :recent, -> { order(created_at: :desc) }

  def self.last_successful = where(status: "ok").recent.first

  def self.stale?(threshold = 2.days)
    last = last_successful
    last.nil? || last.created_at < threshold.ago
  end
end
