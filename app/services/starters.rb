# Which looks a new website can be made from.
#
# A starter is an organization with the starter flag -- see
# db/seeds/starters.rb, which reads them out of the repository. This is the
# small amount of policy around them: which one is offered by default, and what
# happens when somebody asks for one that is not there.
module Starters
  DEFAULT = "starter-plain".freeze

  def self.all = Organization.starters

  def self.find(slug) = Organization.starters.find_by(slug: slug.to_s.presence)

  # A form can ask for anything. An installation that has lost its starters
  # should fail loudly rather than quietly produce a blank website, because a
  # blank website looks like a bug in the editor rather than a missing seed.
  def self.chosen(slug)
    find(slug) || find(DEFAULT) || all.first ||
      raise("no starters on this installation -- run bin/rails db:seed")
  end

  # The name a form posts. Organizations are slugged "starter-trade"; a person
  # choosing a look should see "trade".
  def self.short_name(organization) = organization.slug.delete_prefix("starter-")
end
