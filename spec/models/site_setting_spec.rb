require "rails_helper"

# The parish's own facts used to be constants in Ruby: its name, its address,
# the sentence describing it. That meant the parish could not correct its own
# address without a developer, and -- worse, with a second parish coming -- the
# code asserted which parish it was.
RSpec.describe "what the site says it is", type: :model do
  let(:revision) { Revision.tap { build_page }.open_sandbox }

  around { |ex| Current.set(revision: revision) { ex.run } }

  it "comes from the revision, not from Ruby" do
    revision.site_settings.find_or_create_by!(key: "name").update!(value: "Holy Trinity, Elsewhere")

    expect(SiteDrop.new.name).to eq("Holy Trinity, Elsewhere")
  end

  # A site nobody has told its name should look unconfigured -- NOT like the
  # parish whose code this happens to be.
  it "does not fall back to another parish's details" do
    revision.site_settings.destroy_all

    expect(SiteDrop.new.name).to eq("This site")
    expect(SiteDrop.new.address).to be_blank
    expect(SiteDrop.new.email).to be_blank
  end

  it "reaches anything the parish has named" do
    revision.site_settings.create!(key: "telephone", value: "+1 585 555 0100")

    expect(SiteDrop.new.settings["telephone"]).to eq("+1 585 555 0100")
  end

  # Forgetting this would give every new draft a site with no name.
  it "travels into a new draft" do
    revision.site_settings.find_or_create_by!(key: "name").update!(value: "Holy Trinity, Elsewhere")
    revision.publish!

    draft = Revision.open_sandbox
    expect(draft.site_settings.find_by(key: "name").value).to eq("Holy Trinity, Elsewhere")
  end

  it "refuses a key that could not be read in a template" do
    bad = revision.site_settings.new(key: "Not A Key!", value: "x")

    expect(bad).not_to be_valid
  end

  describe "the AI changing one" do
    it "sets and reports the change" do
      tools = Admin::Tools.new(revision)
      tools.call("set_setting", { "key" => "address", "value" => "1 New Street, Elsewhere" })

      expect(revision.site_settings.find_by(key: "address").value).to eq("1 New Street, Elsewhere")
    end

    it "lists what there is" do
      revision.site_settings.create!(key: "name", value: "Holy Trinity, Elsewhere")
      result = Admin::Tools.new(revision).call("list_settings", {})

      expect(result[:settings].map { |s| s[:key] }).to include("name")
    end
  end
end

# A preview renders one revision while another is live. The site's own name and
# address must come from the revision being RENDERED, not from whichever is
# globally current -- otherwise a preview of next week's draft carries last
# week's address, and nobody notices because both look plausible.
RSpec.describe "which revision's facts a page carries", type: :model do
  it "uses the revision being rendered, not the current one" do
    live = Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox
    live.site_settings.create!(key: "name", value: "The Published Name")
    live.publish!

    draft = Revision.open_sandbox
    draft.site_settings.find_by(key: "name").update!(value: "The Draft Name")

    Current.set(revision: live) do
      expect(SiteDrop.new(draft).name).to eq("The Draft Name")
      expect(SiteDrop.new(live).name).to eq("The Published Name")
      expect(SiteDrop.new.name).to eq("The Published Name")   # falls back to current
    end
  end
end
