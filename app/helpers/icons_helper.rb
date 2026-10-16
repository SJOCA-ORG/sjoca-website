module IconsHelper
  # The icon shown for a given day.
  #
  # Chosen by day of the year, so it changes daily, everyone sees the same one,
  # and it is stable across a page reload. As more icons are added the rotation
  # simply gets longer — no code changes, no list to maintain.
  def icon_of_the_day(date = Date.current)
    names = Photo.published
                       .where("human_name LIKE 'icon-of-the-day-%'")
                       .distinct.order(:human_name).pluck(:human_name)
    return nil if names.empty?

    Photo.newest(names[date.yday % names.size])
  end
end
