require "rails_helper"

# Deleting an organization takes its whole website with it, and nothing else's.
#
# Six associations carry dependent: :destroy and nothing exercised a single one
# of them until the starter-thumbnail script started creating and deleting a
# throwaway organization per look. "Deleting a customer's photographs by
# cascade" is not a thing to find out about afterwards, so it is asserted here.
RSpec.describe "destroying an organization" do
  let!(:keeper) { Organization.sole_tenant or raise "expected one organization" }

  def furnish(org, marker)
    Organization.acting_as(org) do
      revision = Revision.create!(state: "published", title: "live")
      DefaultTemplates.install!(revision)
      revision.site_settings.create!(key: "name", value: marker)
      page = Page.create!(slug: "home", title: marker, nav_title: "Home", revision: revision)
      section = page.sections.create!(style: "plain", revision: revision)
      section.blocks.create!(kind: "text", content: marker, revision: revision)
      bytes = "PNG-#{marker}"
      Photo.create!(human_name: "hero", content_type: "image/png", data: bytes,
                    byte_size: bytes.bytesize, sha256: Photo.digest(bytes),
                    status: "published", version: 1)
      Tag.create!(name: "a-tag", label: "A Tag")
      Lesson.create!(subject: "something", body: "a sentence about #{marker}")
    end
  end

  it "takes its whole website with it" do
    doomed = Organization.create!(name: "Temporary", slug: "temporary")
    doomed.add_host("temporary.example")
    furnish(doomed, "TEMPORARY")

    expect { doomed.destroy! }
      .to change { Revision.unscoped.where(organization_id: doomed.id).count }.to(0)

    %w[Photo Tag Lesson].each do |model|
      expect(model.constantize.unscoped.where(organization_id: doomed.id).count).to eq(0), model
    end
    expect(OrganizationHost.where(organization_id: doomed.id).count).to eq(0)
    expect(Page.unscoped.joins(:revision).where(revisions: { organization_id: doomed.id }).count).to eq(0)
  end

  it "leaves every other organization completely alone" do
    furnish(keeper, "KEEPER")
    before = Organization.acting_as(keeper) do
      { pages: Page.count, photos: Photo.count, tags: Tag.count, lessons: Lesson.count }
    end

    doomed = Organization.create!(name: "Temporary", slug: "temporary")
    doomed.add_host("temporary.example")
    furnish(doomed, "TEMPORARY")
    doomed.destroy!

    after = Organization.acting_as(keeper) do
      { pages: Page.count, photos: Photo.count, tags: Tag.count, lessons: Lesson.count }
    end
    expect(after).to eq(before)
  end

  # An operator's log is about what was done, not about who it was done to.
  # Deleting the organization must not delete the record of deleting it.
  it "keeps the record of what was done to it" do
    doomed = Organization.create!(name: "Temporary", slug: "temporary")
    user = User.create!(email: "operator@example.com", password: "Passw0rd!",
                        role: "superadmin", application_admin: true, organization: nil)
    OperatorAction.note!(:created, organization: doomed, user: user)

    expect { doomed.destroy! }.not_to change(OperatorAction, :count)
    expect(OperatorAction.last.organization).to be_nil
    expect(OperatorAction.last.action).to eq("created")
  end

  # This started out asserting the opposite -- that the people were kept and
  # merely detached -- and the attempt raised PG::CheckViolation: a user with no
  # organization and no application_admin violates the constraint that says
  # everybody must be somewhere, so the destroy failed outright.
  #
  # The constraint was right and the instinct was wrong. An editor account for
  # an organization that no longer exists cannot sign in anywhere, while its
  # email -- unique across the whole system -- goes on blocking that person from
  # being invited to a different one.
  it "takes its editors with it, so their addresses are free again" do
    doomed = Organization.create!(name: "Temporary", slug: "temporary")
    Organization.acting_as(doomed) do
      User.create!(email: "editor@temporary.example", password: "Passw0rd!", role: "superadmin")
    end

    expect { doomed.destroy! }.to change(User, :count).by(-1)

    # And the address can be used again, which is the point.
    expect {
      Organization.acting_as(keeper) do
        User.create!(email: "editor@temporary.example", password: "Passw0rd!", role: "superadmin")
      end
    }.not_to raise_error
  end

  it "leaves an application administrator alone, belonging to nobody" do
    operator = User.create!(email: "operator@example.com", password: "Passw0rd!",
                            role: "superadmin", application_admin: true, organization: nil)
    doomed = Organization.create!(name: "Temporary", slug: "temporary")

    doomed.destroy!

    expect(operator.reload).to be_persisted
    expect(operator.organization_id).to be_nil
  end
end
