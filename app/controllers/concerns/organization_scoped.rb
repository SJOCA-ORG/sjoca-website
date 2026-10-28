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
    before_action :send_them_to_the_canonical_host
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

  # One site, one address.
  #
  # An organization ends up with several hostnames -- a subdomain of the shared
  # domain from the day it is created, then its own domain once somebody points
  # the DNS. Both keep working, which is right, and both serving the same pages
  # is not: search engines treat it as duplicate content, and people bookmark
  # whichever they saw first and never move.
  #
  # So everything that is not the canonical host is a permanent redirect to it.
  # Setting canonical_url at cutover is what makes the staging subdomain quietly
  # start forwarding, and it is the same mechanism that sends a bare
  # example.org to www.example.org -- one feature covering three problems.
  #
  # Three guards, each for a specific way this goes wrong:
  #
  #   GET and HEAD only. A 301 on a POST loses the body, and browsers are
  #   entitled to turn the retry into a GET.
  #
  #   The canonical host must be one of THIS organization's hostnames. A typo in
  #   canonical_url would otherwise take a site off the air by sending every
  #   request somewhere that does not answer -- and if that somewhere is the
  #   same site under another name, a redirect loop.
  #
  #   Off unless the deployment asks for it. In development you reach the app by
  #   whatever name you typed, and localhost redirecting to a production domain
  #   would be a memorable afternoon.
  def send_them_to_the_canonical_host
    return unless Rails.application.config.x.enforce_canonical_host
    return unless request.get? || request.head?

    org = Current.organization
    return if org.nil?

    canonical = URI.parse(org.canonical_url).host.presence rescue nil
    return if canonical.nil? || canonical.casecmp?(request.host)
    return unless org.hosts.include?(canonical.downcase)

    redirect_to("#{org.canonical_url}#{request.fullpath}",
                status: :moved_permanently, allow_other_host: true)
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
