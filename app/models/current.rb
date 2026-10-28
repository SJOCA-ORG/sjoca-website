# Which organization, and which revision, this request is for.
#
# Two attributes, and the order matters: the organization is resolved from the
# hostname first, because Revision.live is itself scoped to an organization and
# answers nothing until one is set.
class Current < ActiveSupport::CurrentAttributes
  attribute :organization, :revision

  # Falls back to the only organization when there is exactly one -- which keeps
  # the console, the seeds, every rake task and a single-organization install
  # working without each of them announcing who they are. It stops falling back
  # the moment a second organization exists. See Organization.sole_tenant.
  def organization = super || (self.organization = Organization.sole_tenant)

  def revision = super || Revision.live
end
