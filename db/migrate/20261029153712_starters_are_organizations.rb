# A starter is an organization, not a folder of YAML.
#
# It was files on disk: a manifest, some Liquid, a stylesheet. Which meant a
# new look had to be written by a developer who knew the block kinds and the
# class names -- and could get them wrong twice without anything noticing --
# and it meant a starter could not contain a single photograph, because there
# is no way to put bytes in a manifest. The starter whose whole premise is
# showing pictures had none.
#
# As an organization it is built by USING the product: asked for in plain
# words, previewed, reverted, looked at. And creating a customer's site becomes
# a copy of one organization's live revision into another -- which is
# Revision.open_sandbox taking a target instead of assuming one, a method that
# already copies templates, theme assets, settings, data sources, pages,
# sections and blocks in the right order and is exercised on every draft.
#
# The flag keeps them out of the places a customer belongs: the accounts list,
# the single-organization fallback, anything that will one day send an invoice.
class StartersAreOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :starter, :boolean, null: false, default: false
    add_index  :organizations, :starter, where: "starter"
  end
end
