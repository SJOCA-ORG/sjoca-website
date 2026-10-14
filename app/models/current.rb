# Which revision this request renders. The live site sets the published one;
# /preview/:id sets another. Everything that reads content scopes through here.
class Current < ActiveSupport::CurrentAttributes
  attribute :revision

  def revision = super || Revision.live
end
