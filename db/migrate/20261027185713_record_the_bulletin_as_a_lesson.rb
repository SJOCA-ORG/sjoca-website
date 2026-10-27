# What Ruby used to know about bulletins, written down where it belongs.
#
# add_bulletin, list_bulletins and their helpers knew that a bulletin is four
# sheets of 5.5 x 8.5, dated to a Sunday, and made by copying last week's. That
# is not a fact about websites; it is a fact about THIS parish. It is a lesson —
# the AI's own stored knowledge — and the tools are gone, replaced by add_page,
# copy_page and add_sections, which know nothing about parishes.
#
# A different parish will record a different lesson, or none.
class RecordTheBulletinAsALesson < ActiveRecord::Migration[8.1]
  BODY = <<~TEXT.strip
    This parish makes a weekly bulletin: a page with layout "bulletin", dated on
    the Sunday it is for, kept off the website (on_website: false) because it is
    printed and emailed rather than published. Four sheets of 5.5 x 8.5 in reading
    order — the printer folds them. Make this week's by adding the page and using
    copy_page to bring last week's across, then recompute only what is dated: the
    day's commemoration, the readings, that week's services. Leave the masthead,
    the address, the giving line and the standing reminders exactly as they are.
    Check it fits before saying it is finished.
  TEXT

  def up
    return if select_value("SELECT 1 FROM lessons WHERE subject = 'bulletin'")

    now = Time.current
    execute(<<~SQL)
      INSERT INTO lessons (subject, body, learned_in, active, created_at, updated_at)
      VALUES ('bulletin', #{quote(BODY)}, 'moved out of Ruby, 27 October 2026', true,
              #{quote(now)}, #{quote(now)})
    SQL
  end

  def down
    execute("DELETE FROM lessons WHERE subject = 'bulletin'")
  end
end
