# This table's rows belong to one organization, and no query may see another's.
#
# The scope is a default_scope on purpose, and it is the whole safety argument
# of multi-organization hosting in this app. There are 67 admin tools, a Liquid
# renderer, a photo library and a dozen controllers, and auditing each of them
# for a missing `where` would be a job with no end. Instead the filter sits
# UNDER all of them, in the one place every query passes through.
#
# It holds because nothing in app/ reaches past ActiveRecord: no raw SQL, no
# find_by_sql, no unscoped. spec/requests/organization_isolation_spec.rb proves
# that, and fails if it stops being true.
#
# WITH NO ORGANIZATION SET, THESE MODELS RETURN NOTHING. That is deliberate.
# A job, a script or a controller that has not said which organization it means
# gets an empty result rather than the first one it finds -- so the failure is
# "nothing is here", which gets investigated, and never "here is somebody
# else's", which does not.
module BelongsToOrganization
  extend ActiveSupport::Concern

  included do
    belongs_to :organization

    default_scope { where(organization_id: Current.organization&.id) }

    # So nothing has to remember. Every create in the app -- in a tool, a
    # controller, a seed -- lands in the organization the request is for.
    before_validation { self.organization ||= Current.organization }
  end
end
