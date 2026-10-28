# Which organization this request is for, decided by the hostname.
#
# This runs before everything -- before the revision is chosen, before the login
# is checked -- because Revision.live is itself scoped to an organization and
# answers nothing until one is set. Include it in ApplicationController and
# nowhere else; order of inclusion is the order of before_actions.
#
# An unknown hostname gets 404, not the first organization in the table. The one
# exception is while there is exactly one organization, when an unrecognised
# host falls through to it -- so a new deployment answers on whatever address the
# platform gives it before anyone has written that address down. That
# forgiveness ends automatically the day a second organization exists, which is
# the day it would start handing one organization's site to another's visitors.
module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_organization
    helper_method :current_organization
  end

  private

  def set_organization
    Current.organization = Organization.by_host(request.host) || Organization.sole_tenant

    return if Current.organization

    # Deliberately terse, and deliberately not "unknown host: x". An error page
    # that repeats back what was asked for is a way of telling a scanner which
    # of its guesses were close.
    render plain: "Not found", status: :not_found
  end

  def current_organization = Current.organization
end
