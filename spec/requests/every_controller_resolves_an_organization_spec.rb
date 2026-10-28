require "rails_helper"

# A controller that does not descend from ApplicationController belongs to no
# organization.
#
# Hostname resolution is a before_action in ApplicationController. Anything
# reached by a route that inherits from ActionController::Base directly skips it
# entirely: Current.organization stays nil, the scoped models answer nothing,
# and -- while there is exactly one organization -- everything still appears to
# work, because Current.organization finds the only one by itself.
#
# That is what happened to the web app manifest. It was served by Rails' own
# rails/pwa#manifest and fell back to "This site" the moment a second
# organization existed, which nobody would have seen until a customer installed
# the app on a phone and found it named after nothing.
#
# So the check is mechanical and over every route the app answers, rather than
# over the ones somebody thought to look at.
RSpec.describe "every controller resolves an organization" do
  # Engine and framework routes we do not serve ourselves. Each is here because
  # it serves no organization's content -- not because it was inconvenient.
  # Rails::Health is the load balancer's probe at /up, and it MUST stay outside
  # this tree. Render asks for it on whatever hostname it likes, and an
  # organization-resolving controller would answer 404 and have the service
  # declared unhealthy -- taking every organization down to protect a page that
  # serves none of them.
  NOT_OURS = %w[
    ActiveStorage ActionMailbox ActionCable Rails::Conductor Rails::Info
    Rails::MailersController Rails::HealthController Turbo::Native ActiveRecord
  ].freeze

  def our_controllers
    Rails.application.routes.routes.filter_map { |r|
      ctrl = r.defaults[:controller]
      next if ctrl.blank?
      next if NOT_OURS.any? { |prefix| "#{ctrl.camelize}Controller".start_with?(prefix) }

      ctrl
    }.uniq.sort
  end

  it "finds the application's own routes" do
    expect(our_controllers).to include("pages", "admin/revisions", "pwa")
  end

  # Includes OrganizationScoped, rather than descends from
  # ApplicationController. Those are the same thing today, and the first is the
  # one that matters: inheritance is how the concern happens to arrive, and a
  # controller that got it another way is just as correct.
  it "has every one of them resolving an organization" do
    strays = our_controllers.filter_map do |name|
      klass = "#{name.camelize}Controller".safe_constantize
      next "#{name} (no such controller)" if klass.nil?
      next if klass.include?(OrganizationScoped)

      "#{name} -> #{klass} < #{klass.superclass}"
    end

    expect(strays).to be_empty, <<~MSG
      These controllers never learn which organization the request is for:

        #{strays.join("\n        ")}

      OrganizationScoped is the only place a request resolves a hostname to an
      organization. A controller without it answers with none set -- which looks
      fine while there is one, because Current.organization finds the only one
      by itself, and serves placeholders or nothing once there are two.

      Either include it (normally by descending from ApplicationController), or
      add it to NOT_OURS with a sentence saying whose content it serves instead.
    MSG
  end

  # The other half: having the before_action is no use if something skips it.
  it "nothing skips the organization callback" do
    offences = Dir[Rails.root.join("app/controllers/**/*.rb")].filter_map do |path|
      body = File.read(path)
      next unless body =~ /skip_before_action[^\n]*set_organization/

      Pathname(path).relative_path_from(Rails.root).to_s
    end

    expect(offences).to be_empty,
      "these skip organization resolution: #{offences.join(', ')}"
  end
end
