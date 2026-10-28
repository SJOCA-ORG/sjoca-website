require "rails_helper"

# The console for whoever runs this app for other people.
#
# Two things are being tested, and the second matters more than the first. One:
# that it works -- an account can be created, invited, suspended. Two: that it
# is unreachable by everybody else, and that using it leaves a trace.
#
# An application admin can act inside any customer's data. That power cannot be
# made smaller -- somebody has to be able to fix a club's broken page on a
# Tuesday evening -- so it is made accountable instead, and these specs are
# where "accountable" is checked rather than claimed.
# signed_out: true because the suite's global hook signs in as this parish's
# own superadmin before every request spec, and every example here is about who
# is signed in. The helper is sign_in_at rather than sign_in for the same
# reason: redefining sign_in broke that hook for the whole file.
RSpec.describe "the operator console", type: :request, signed_out: true do
  let!(:product) do
    org = Organization.sole_tenant or raise "expected one organization to start from"
    org.update!(product: true, canonical_url: "https://builder.example")
    org.add_host("builder.example")
    Organization.acting_as(org) do
      revision = Revision.create!(state: "published", title: "live")
      DefaultTemplates.install!(revision)
      Page.create!(slug: "home", title: "Builder", nav_title: "Home", revision: revision)
    end
    org
  end

  let!(:operator) do
    User.create!(email: "operator@example.com", password: "Passw0rd!",
                 role: "superadmin", application_admin: true, organization: nil)
  end

  let!(:customer) do
    org = Organization.create!(name: "Woodwind Society", slug: "woodwind",
                              canonical_url: "https://woodwind.example")
    org.add_host("woodwind.example")
    Organization.acting_as(org) do
      revision = Revision.create!(state: "published", title: "live")
      DefaultTemplates.install!(revision)
      Page.create!(slug: "home", title: "Woodwind", nav_title: "Home", revision: revision)
      User.create!(email: "editor@woodwind.example", password: "Passw0rd!", role: "superadmin")
    end
    org
  end

  def sign_in_at(email, host:)
    host! host
    post admin_login_path, params: { session: { email: email, password: "Passw0rd!" } }
  end

  describe "who may be here" do
    it "lets an application admin in, on the product's hostname" do
      sign_in_at "operator@example.com", host: "builder.example"
      get operator_root_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Woodwind Society")
    end

    # 404 and not 403: a customer's administrator poking at /operator should
    # not learn whether it exists.
    it "shows a customer's own superadmin nothing, and does not admit to existing" do
      sign_in_at "editor@woodwind.example", host: "woodwind.example"
      get operator_root_path
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("Accounts")
    end

    it "turns away a stranger" do
      host! "builder.example"
      get operator_root_path
      expect(response).to redirect_to(admin_login_path)
    end

    # The console answers on the product's hostname only. An application admin
    # signing in on a customer's domain should be rare; from one, the console is
    # not merely refused, it is absent.
    it "does not answer on a customer's hostname, even to an application admin" do
      sign_in_at "operator@example.com", host: "woodwind.example"
      get operator_root_path
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "what it shows" do
    before { sign_in_at "operator@example.com", host: "builder.example" }

    it "lists accounts with their hostnames and sizes" do
      get operator_root_path
      expect(response.body).to include("woodwind.example")
      expect(response.body).to include("woodwind")        # the slug
      expect(response.body).to match(/1 page/)
    end

    # It lists accounts; it does not display their content. Going into an
    # organization is a separate act that leaves a row.
    it "does not show a customer's page content" do
      Organization.acting_as(customer) do
        page = Page.in_revision(Revision.live).find_by(slug: "home")
        section = page.sections.create!(style: "plain", revision: Revision.live)
        section.blocks.create!(kind: "text", content: "PRIVATE-DRAFT-WORDS", revision: Revision.live)
      end

      get operator_root_path
      expect(response.body).not_to include("PRIVATE-DRAFT-WORDS")
    end
  end

  describe "creating an organization" do
    before { sign_in_at "operator@example.com", host: "builder.example" }

    it "creates a working website and invites its owner" do
      expect {
        post operator_organizations_path, params: {
          name: "Fife and Drum", slug: "fife", host: "fife.example",
          owner_email: "owner@fife.example"
        }
      }.to change(Organization, :count).by(1)

      org = Organization.find_by(slug: "fife")
      expect(org.hosts).to include("fife.example")
      expect(org.canonical_url).to eq("https://fife.example")

      Organization.acting_as(org) do
        expect(Revision.live).to be_present
        expect(Revision.live.templates.count).to eq(DefaultTemplates.all.size)
        expect(Page.in_revision(Revision.live).find_by(slug: "home")).to be_present
        expect(User.find_by(email: "owner@fife.example")).to be_present
      end

      # And it actually serves, which is the only claim worth making.
      host! "fife.example"
      get "/"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fife and Drum")
    end

    it "sends the owner an invitation that works" do
      perform_enqueued_jobs do
        post operator_organizations_path, params: {
          name: "Fife and Drum", slug: "fife", host: "fife.example",
          owner_email: "owner@fife.example"
        }
      end

      # Found by WHO IT IS ADDRESSED TO, not by position. Both deliveries and
      # the enqueued-job list outlive an example, so perform_enqueued_jobs also
      # runs whatever earlier examples left behind -- and .last was then some
      # other spec's password reset. This passed alone and failed in the suite
      # twice before the assertion stopped depending on ordering.
      mail = ActionMailer::Base.deliveries.find { |m| m.to == ["owner@fife.example"] }
      expect(mail).to be_present
      expect(mail.subject).to include("Fife and Drum")

      # Follow the link that is actually in the email, rather than pulling the
      # token out and rebuilding the URL. Two reasons, and the second cost an
      # hour: mail.body.encoded is raw MIME, where quoted-printable writes "=3D"
      # for every "="; and the token in the URL is percent-encoded, so handing
      # it back to a path helper encodes it a second time. The emailed token
      # came out four characters longer than a real one and resolved to nobody.
      #
      # Requesting the URL as a browser would tests the thing that was sent.
      body = mail.text_part&.decoded || mail.body.decoded
      link = body[%r{https?://\S+}]
      expect(link).to include("fife.example")

      invitation = URI.parse(link)
      host! invitation.host
      get invitation.request_uri

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Choose a password")
    end

    # All of it or none. A hostname with no revision is worse than nothing,
    # because the next attempt collides with the leftovers.
    it "creates nothing at all when something is wrong" do
      before_count = Organization.count

      post operator_organizations_path, params: {
        name: "Clashing", slug: "clash", host: "woodwind.example",  # already taken
        owner_email: "owner@clash.example"
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(Organization.count).to eq(before_count)
      expect(User.find_by(email: "owner@clash.example")).to be_nil
    end

    it "refuses an owner email that already has an account" do
      before_count = Organization.count

      post operator_organizations_path, params: {
        name: "Twice", slug: "twice", host: "twice.example",
        owner_email: "editor@woodwind.example"
      }

      expect(Organization.count).to eq(before_count)
    end
  end

  describe "the record of what was done" do
    before { sign_in_at "operator@example.com", host: "builder.example" }

    it "writes a row when an organization is created, and who by" do
      post operator_organizations_path, params: {
        name: "Fife and Drum", slug: "fife", host: "fife.example",
        owner_email: "owner@fife.example"
      }

      action = OperatorAction.newest_first.find_by(action: "created")
      expect(action.organization.slug).to eq("fife")
      expect(action.user).to eq(operator)
      expect(action.ip).to be_present
    end

    # The row that matters most: an operator looking at somebody else's data.
    it "writes a row when an operator goes into a customer's admin" do
      expect {
        post enter_operator_organization_path(customer)
      }.to change { OperatorAction.where(action: "entered").count }.by(1)

      action = OperatorAction.where(action: "entered").newest_first.first
      expect(action.organization).to eq(customer)
      expect(action.user).to eq(operator)
      expect(response).to redirect_to("https://woodwind.example/admin")
    end

    it "shows the log on the console" do
      post enter_operator_organization_path(customer)
      get operator_root_path

      expect(response.body).to include("entered")
      expect(response.body).to include("operator@example.com")
    end
  end

  describe "suspending" do
    before { sign_in_at "operator@example.com", host: "builder.example" }

    it "marks it suspended, keeps every row, and says so" do
      pages = Organization.acting_as(customer) { Page.count }

      post suspend_operator_organization_path(customer)

      expect(customer.reload).not_to be_active
      expect(Organization.acting_as(customer) { Page.count }).to eq(pages)
      expect(flash[:notice]).to include("Nothing was deleted")
    end

    it "can be undone" do
      post suspend_operator_organization_path(customer)
      post resume_operator_organization_path(customer)
      expect(customer.reload).to be_active
    end
  end

  # Designating the first product organization needs a console, and the console
  # needs a product organization. So while there is none it answers anywhere,
  # and says so on the page rather than leaving it to be discovered.
  describe "before any organization is the product" do
    it "answers on any hostname, with a warning" do
      product.update!(product: false)

      sign_in_at "operator@example.com", host: "woodwind.example"
      get operator_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No organization is marked as this tool's own site")
    end
  end
end
