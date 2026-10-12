class AddSelfNavTitleToPages < ActiveRecord::Migration[8.1]
  def change
    # A parent page with children is otherwise invisible: hovering shows only
    # the children, so nothing suggests the parent has content of its own.
    # When set, the parent appears as the first item in its own submenu under
    # this label.
    #
    # The old site solved this by duplicating content -- /about-us and
    # /about-us/our-story are the same page twice, which means editing it twice.
    add_column :pages, :self_nav_title, :string
  end
end
