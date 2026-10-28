# The web app manifest and the service worker.
#
# These were served by Rails' built-in rails/pwa#manifest, which descends from
# Rails::ApplicationController and therefore never ran our before_actions -- so
# no organization was resolved and the manifest fell back to SiteDrop's "This
# site" for everybody. Harmless while there was one organization, because
# Current.organization finds the only one by itself. Wrong the moment there are
# two: every organization's phone-installed app would carry the same
# placeholder name.
#
# Ours now, so it inherits the hostname resolution like every other request.
# The general rule this is an instance of: a controller that does not include
# OrganizationScoped belongs to no organization, and
# spec/requests/every_controller_resolves_an_organization_spec.rb says so of
# every route the app answers.
#
# Otherwise a faithful copy of Rails' version, and the two lines it leaves out
# are both load-bearing:
#
#   skip_forgery_protection -- a plain GET that renders JavaScript trips
#   ActionController::InvalidCrossOriginRequest, which is Rails protecting
#   against a <script src> reading a logged-in user's data. A service worker is
#   fetched by the browser runtime, not by a page, so the check does not apply.
#
#   no explicit content_type -- the template extension decides it. Naming
#   "application/manifest+json" by hand is more correct by the spec and was a
#   silent behaviour change, which is not a thing to do while moving a file.
class PwaController < ApplicationController
  skip_forgery_protection

  def service_worker
    render template: "pwa/service-worker", layout: false
  end

  def manifest
    render template: "pwa/manifest", layout: false
  end
end
