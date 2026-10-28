require "rails_helper"

# Can one organization see another's?
#
# Everything else in this suite runs with a single organization, where a missing
# scope is invisible: there is only one answer, so the wrong query gives the
# right result. This is the spec where that stops being true. Two organizations
# exist, each with its own content, photographs, tags and editor, and the
# question asked of every surface a stranger can reach is the same one: does
# anything of B's appear when you ask A?
#
# A failure here is not a bug, it is a disclosure. These organizations are other
# people's -- their members' photographs, their drafts, their editors' accounts.
RSpec.describe "one organization cannot see another", type: :request do
  let!(:first) do
    org = Organization.create!(name: "First Assembly", slug: "first")
    org.add_host("first.example")
    furnish(org, "FIRST-ONLY-TEXT", "first-hero", "first-tag", "editor@first.example")
    org
  end

  let!(:second) do
    org = Organization.create!(name: "Second Society", slug: "second")
    org.add_host("second.example")
    furnish(org, "SECOND-ONLY-TEXT", "second-hero", "second-tag", "editor@second.example")
    org
  end

  # One published home page, one photograph, one tag, one editor -- each
  # carrying a string that could only have come from this organization.
  def furnish(org, marker, photo_name, tag_name, email)
    Organization.acting_as(org) do
      revision = Revision.create!(state: "published", title: "live")
      DefaultTemplates.install!(revision)
      page = Page.create!(slug: "home", title: marker, nav_title: marker, revision: revision)
      section = page.sections.create!(style: "plain", revision: revision)
      section.blocks.create!(kind: "text", content: marker, revision: revision)

      # A second page whose slug could only be this organization's, so the
      # sitemap can be told apart. Both home pages render as "/", which makes
      # them useless for telling anything apart.
      Page.create!(slug: "about-#{org.slug}", title: "About", nav_title: "About",
                   revision: revision)

      bytes = "PNG-#{marker}"
      Photo.create!(human_name: photo_name, content_type: "image/png", data: bytes,
                    byte_size: bytes.bytesize, sha256: Photo.digest(bytes),
                    status: "published", version: 1)
      Tag.create!(name: tag_name, label: tag_name.titleize)
      User.create!(email: email, password: "Passw0rd!", role: "superadmin")
    end
  end

  def sign_in_as(email, host:)
    host! host
    post admin_login_path, params: { session: { email: email, password: "Passw0rd!" } }
  end

  describe "the public website" do
    it "serves each organization its own home page" do
      host! "first.example"
      get "/"
      expect(response.body).to include("FIRST-ONLY-TEXT")
      expect(response.body).not_to include("SECOND-ONLY-TEXT")

      host! "second.example"
      get "/"
      expect(response.body).to include("SECOND-ONLY-TEXT")
      expect(response.body).not_to include("FIRST-ONLY-TEXT")
    end

    # The photograph route takes a name, and names are only unique within an
    # organization. Asking first.example for second-hero must not find it --
    # otherwise every photograph in the system is readable by guessing names,
    # and names are guessable on purpose.
    it "will not serve another organization's photograph, even named exactly" do
      host! "first.example"
      get "/media/second-hero"
      expect(response).to have_http_status(:not_found)

      get "/media/first-hero"
      expect(response).to have_http_status(:ok)
    end

    it "lists only its own pages in the sitemap" do
      host! "first.example"
      get "/sitemap.xml"
      expect(response.body).to include("about-first")
      expect(response.body).not_to include("about-second")

      host! "second.example"
      get "/sitemap.xml"
      expect(response.body).to include("about-second")
      expect(response.body).not_to include("about-first")
    end

    # With two organizations there is no "the" organization to fall back to.
    it "answers an unrecognised hostname with 404 and nothing else" do
      host! "someone-elses-domain.example"
      get "/"
      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include("FIRST-ONLY-TEXT")
      expect(response.body).not_to include("SECOND-ONLY-TEXT")
      expect(response.body).not_to include("someone-elses-domain")
    end
  end

  describe "the admin" do
    it "lets an editor in at their own organization" do
      sign_in_as "editor@first.example", host: "first.example"
      get admin_root_path
      expect(response).to have_http_status(:ok)
    end

    # The attack this closes is not subtle and not unlikely: an editor of one
    # organization types another organization's address. The cookie is valid and
    # the user is real; only the organization is wrong.
    it "refuses the same signed-in session at another organization" do
      sign_in_as "editor@first.example", host: "first.example"

      host! "second.example"
      get admin_root_path
      expect(response).to redirect_to(admin_login_path)
    end

    it "will not sign in an editor of one organization at another's address" do
      sign_in_as "editor@first.example", host: "second.example"
      get admin_root_path
      expect(response).to redirect_to(admin_login_path)
    end

    it "shows an editor only their own photographs" do
      sign_in_as "editor@first.example", host: "first.example"
      get admin_photos_path
      expect(response.body).to include("first-hero")
      expect(response.body).not_to include("second-hero")
    end

    it "shows an editor only their own revisions" do
      sign_in_as "editor@first.example", host: "first.example"
      get admin_root_path

      ids = Organization.acting_as(second) { Revision.pluck(:id) }
      ids.each { |id| expect(response.body).not_to match(/revisions\/#{id}\b/) }
    end

    # Guessing an id is the oldest trick there is, and the one a default_scope
    # actually stops: the row is not hidden from the view, it is absent from
    # the query.
    it "cannot reach another organization's revision by its id" do
      id = Organization.acting_as(second) { Revision.live.id }

      sign_in_as "editor@first.example", host: "first.example"
      get status_admin_revision_path(id)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "an application administrator" do
    let!(:operator) do
      User.create!(email: "operator@example.com", password: "Passw0rd!",
                   role: "superadmin", application_admin: true, organization: nil)
    end

    it "belongs to no organization and is allowed to anyway" do
      expect(operator.organization).to be_nil
      expect(operator.may_act_in?(first)).to be(true)
      expect(operator.may_act_in?(second)).to be(true)
    end

    it "may sign in at either organization" do
      sign_in_as "operator@example.com", host: "first.example"
      get admin_root_path
      expect(response).to have_http_status(:ok)

      sign_in_as "operator@example.com", host: "second.example"
      get admin_root_path
      expect(response).to have_http_status(:ok)
    end

    # Reach, not blindness: an application admin sees ONE organization at a
    # time, the one whose address they are on. There is no view of everybody's
    # data at once, which is what makes the access reviewable.
    it "sees one organization at a time, not all of them" do
      sign_in_as "operator@example.com", host: "first.example"
      get admin_photos_path
      expect(response.body).to include("first-hero")
      expect(response.body).not_to include("second-hero")
    end
  end

  describe "names may repeat across organizations" do
    it "allows the same photograph name to exist for both" do
      expect {
        Organization.acting_as(second) do
          bytes = "PNG-also"
          Photo.create!(human_name: "first-hero", content_type: "image/png", data: bytes,
                        byte_size: bytes.bytesize, sha256: Photo.digest(bytes),
                        status: "published", version: 1)
        end
      }.not_to raise_error
    end

    it "allows the same tag name to exist for both" do
      expect { Organization.acting_as(second) { Tag.create!(name: "first-tag", label: "First Tag") } }
        .not_to raise_error
    end

    # But an email is one person, wherever they work.
    #
    # Enforced by index_users_on_lower_email and NOT by a validation -- the
    # model has never validated email uniqueness, so this raises from the
    # database rather than from Rails. Worth asserting the real exception
    # rather than the one that would be tidier, because the difference is
    # exactly what somebody would hit when writing a sign-up form.
    it "still refuses the same email twice" do
      expect {
        Organization.acting_as(second) do
          User.create!(email: "editor@first.example", password: "Passw0rd!", role: "superadmin")
        end
      }.to raise_error(ActiveRecord::RecordNotUnique, /email/i)
    end
  end
end
