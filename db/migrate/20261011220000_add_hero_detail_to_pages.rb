class AddHeroDetailToPages < ActiveRecord::Migration[8.1]
  def change
    # A line of practical detail under the hero title — service times, in
    # practice. Lets the thing most visitors came for sit at the very top of
    # the page rather than below the fold.
    add_column :pages, :hero_detail, :text
  end
end
