# What a page says about itself in a search result.
#
# Every page was sharing one description -- the parish's general blurb -- which
# tells a search engine that twelve pages are about the same thing, and tells a
# person nothing about which one to click.
class AddDescriptionToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :description, :string
  end
end
