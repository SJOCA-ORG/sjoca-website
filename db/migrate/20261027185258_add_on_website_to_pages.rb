# Some pages are made here but do not belong on the website.
#
# A bulletin is the case that prompted it: built weekly with the parish's own
# styles, photographs, people and data, then printed and emailed — and there is
# no reason for it to be a web page at all. Published, it is four stale pages a
# week accumulating at an address nobody visits, offered to Google, carrying
# names and birthdays that then need editing to be safe in public.
#
# Not on the website, it is simply a document the parish makes.
class AddOnWebsiteToPages < ActiveRecord::Migration[8.1]
  def change
    # Default true: every page that exists today is on the website, and a new
    # page is a web page unless somebody says otherwise.
    add_column :pages, :on_website, :boolean, null: false, default: true
    add_index :pages, %i[revision_id on_website]
  end
end
