require "rails_helper"

# The one message this system sends: "here is how to get back in."
#
# There were no specs for it at all, which is a poor place to have none -- it is
# the only email a stranger can cause the app to send, it carries a signed token,
# and with more than one organization it has to carry the RIGHT organization's
# name, address and hostname.
RSpec.describe UserMailer do
  let(:organization) do
    org = Organization.sole_tenant or raise "expected one organization"
    org.update!(canonical_url: "https://first.example",
                contact_name: "The Secretary", contact_email: "secretary@first.example")
    org.add_host("first.example") unless org.hosts.include?("first.example")
    org
  end
  let(:user) { User.create!(email: "editor@first.example", password: "Passw0rd!", role: "superadmin") }

  def reset_mail(settings: {})
    Organization.acting_as(organization) do
      revision = Revision.create!(state: "published", title: "live")
      DefaultTemplates.install!(revision)
      settings.each { |k, v| revision.site_settings.create!(key: k.to_s, value: v) }
      Current.revision = revision
      UserMailer.password_reset(user, user.generate_token_for(:password_reset))
    end
  end

  it "signs itself with the website's own name, not the product's" do
    mail = reset_mail(settings: { name: "First Assembly" })
    expect(mail[:from].to_s).to include("First Assembly")
    expect(mail.subject).to include("First Assembly")
  end

  # The link has nothing to be relative to, and must point at the organization
  # the person is actually trying to get into -- not at whatever SITE_URL was
  # set to when the process booted.
  it "links to the organization's own hostname" do
    mail = reset_mail(settings: { name: "First Assembly" })
    expect(mail.body.encoded).to include("https://first.example")
  end

  describe "where a reply goes" do
    it "to the website's public address when it has one" do
      mail = reset_mail(settings: { name: "First Assembly", email: "office@first.example" })
      expect(mail.reply_to).to eq(["office@first.example"])
    end

    # Then the ACCOUNT contact: a person who can act, rather than a mailbox
    # nobody reads. Somebody locked out is the likeliest person to reply.
    it "to the account contact when the website offers none" do
      mail = reset_mail(settings: { name: "First Assembly" })
      expect(mail.reply_to).to eq(["secretary@first.example"])
      expect(mail[:reply_to].to_s).to include("The Secretary")
    end

    it "to the envelope sender when there is neither" do
      organization.update!(contact_email: nil, contact_name: nil)
      mail = reset_mail(settings: { name: "First Assembly" })
      expect(mail.reply_to).to be_present
    end
  end

  # THE ONE THAT MATTERS, and the one that was missing.
  #
  # This mail is sent with deliver_later, so it is rendered in a worker process:
  # no request, no hostname, nothing current. Clearing CurrentAttributes is what
  # that looks like from in here -- and without it, a spec that renders the mail
  # inline passes while production sends "This site" and a link to localhost.
  describe "rendered in a worker, as it really is" do
    it "still carries the right organization" do
      organization
      user
      Organization.create!(name: "Another", slug: "another")   # so nothing is implicit

      Organization.acting_as(organization) do
        revision = Revision.create!(state: "published", title: "live")
        DefaultTemplates.install!(revision)
        revision.site_settings.create!(key: "name", value: "First Assembly")
      end

      mail = UserMailer.password_reset(user, user.generate_token_for(:password_reset),
                                       organization: organization)

      ActiveSupport::CurrentAttributes.clear_all
      body = mail.body.encoded   # rendering happens here, with nothing current

      expect(mail.subject).to include("First Assembly")
      expect(body).to include("https://first.example")
      expect(mail.subject).not_to include("This site")
    end

    it "survives the round trip through the queue" do
      organization
      user
      Organization.create!(name: "Another", slug: "another")

      Organization.acting_as(organization) do
        revision = Revision.create!(state: "published", title: "live")
        DefaultTemplates.install!(revision)
        revision.site_settings.create!(key: "name", value: "First Assembly")
      end

      UserMailer.password_reset(user, user.generate_token_for(:password_reset),
                                organization: organization).deliver_later

      ActiveSupport::CurrentAttributes.clear_all
      perform_enqueued_jobs

      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to include("First Assembly")
      expect(mail.body.encoded).to include("https://first.example")
    end
  end

  it "says nothing of this parish when the organization has not been configured" do
    mail = reset_mail
    expect(mail.subject).not_to match(ThisParish::PATTERN)
    expect(mail.body.encoded).not_to match(ThisParish::PATTERN)
  end
end
