# A bulletin is a page like any other -- sections, columns, blocks, templates,
# revisions -- with two things an ordinary page does not have.
#
# A LAYOUT. The site page flows; the bulletin is 5.5 x 8.5 and can actually
# fail to fit. The layout decides which page template renders it and which
# stylesheet applies, and it is what the fit check keys on.
#
# A DATE. Bulletins accumulate, which is the point: an archive of them is the
# visible currency the survey asked for more than it asked for anything else.
# The date is also what the computed parts are computed FOR -- readings and
# services belong to a Sunday, not to whenever somebody happened to edit.
class AddBulletinFieldsToPages < ActiveRecord::Migration[8.1]
  def change
    add_column :pages, :layout, :string, null: false, default: "page"
    add_column :pages, :dated_on, :date

    add_index :pages, %i[revision_id layout]
    add_index :pages, %i[revision_id dated_on]
  end
end
