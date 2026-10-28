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
    around_action :in_the_organizations_time_and_language
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

  # config.time_zone is one value for the whole deployment, and it is currently
  # "America/New_York" -- one organization's clock applied to everybody's dates.
  # An organization keeps its own, and so does a club in Berlin.
  #
  # around_action rather than before_action: Time.use_zone restores the previous
  # zone afterwards, so a request cannot leave a thread set to somebody else's
  # clock for whatever runs next on it.
  def in_the_organizations_time_and_language
    org = Current.organization
    return yield if org.nil?

    Time.use_zone(org.time_zone) do
      I18n.with_locale(org.locale) { yield }
    end
  end

  def current_organization = Current.organization
end
