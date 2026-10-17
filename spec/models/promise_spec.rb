require "rails_helper"

# Standing promises: things that should stay true after the next change.
RSpec.describe Promise do
  let(:promise) do
    described_class.create!(summary: "The home page shows when services are held",
                            intent: "Schedule accuracy was the survey's first concern.",
                            script: "return { pass: true }", page_slug: "home")
  end

  # The whole scheme rests on an id always meaning the same assertion. Editing
  # one in place would rewrite history: a revision's list would silently start
  # promising something different from what it promised when it was approved.
  it "cannot be edited once written" do
    expect { promise.update!(summary: "something else") }
      .to raise_error(ActiveRecord::ReadOnlyRecord, /immutable/)
  end

  it "says where it applies" do
    expect(promise.scope_text).to eq("/home")
    expect(described_class.new(page_slug: nil).scope_text).to eq("every page")
  end

  describe "a revision's list" do
    let(:live)  { test_revision.tap { build_page } }
    let(:draft) { live && Revision.open_sandbox }

    it "is copied when a sandbox is opened" do
      live.revision_promises.create!(promise: promise)
      fresh = Revision.open_sandbox

      expect(fresh.promises).to include(promise)
    end

    it "shares the promise rather than duplicating it" do
      live.revision_promises.create!(promise: promise)
      expect { Revision.open_sandbox }.not_to change(described_class, :count)
    end

    # A diff of two revisions' lists IS the history of what the site promises.
    it "reports what a revision added and removed" do
      kept    = described_class.create!(summary: "Kept", intent: "x", script: "return {pass:true}")
      dropped = described_class.create!(summary: "Dropped", intent: "y", script: "return {pass:true}")
      live.revision_promises.create!(promise: kept)
      live.revision_promises.create!(promise: dropped)

      d = Revision.open_sandbox
      d.revision_promises.find_by(promise: dropped).destroy
      d.revision_promises.create!(promise: promise)

      changes = d.promise_changes
      expect(changes[:added].map(&:summary)).to eq([promise.summary])
      expect(changes[:removed].map(&:summary)).to eq(["Dropped"])
    end
  end

  describe "the tools" do
    let(:live)  { test_revision.tap { build_page(slug: "home", title: "Home", nav_title: "Home") } }
    let(:draft) { live && Revision.open_sandbox }
    let(:tools) { Admin::Tools.new(draft) }

    it "refuses to remove a promise without a reason" do
      draft.revision_promises.create!(promise: promise)
      expect { tools.call("remove_promise", { "id" => promise.id }) }
        .to raise_error(Admin::Tools::ToolError, /because/)
    end

    it "names what was dropped and how long it stood" do
      draft.revision_promises.create!(promise: promise)
      result = tools.call("remove_promise",
                          { "id" => promise.id, "because" => "the page was retired" })

      expect(result[:summary]).to include("services are held")
      expect(result[:summary]).to include("the page was retired")
    end

    it "lists what each promise is for, not only its summary" do
      draft.revision_promises.create!(promise: promise)
      listed = tools.call("list_promises", {})[:promises].first

      expect(listed[:intent]).to match(/survey/)
    end
  end
end
