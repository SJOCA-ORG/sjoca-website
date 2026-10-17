require "rails_helper"

# Liquid renders an unknown property as an empty string and says NOTHING. A
# template asking for {{ photo.caption }} when the property is alt produces a
# page with blank captions, no error, and nothing in any log. The AI did exactly
# this -- it invented `special`, `date` and `place` writing a calendar template,
# having already read the guide that lists the real ones.
RSpec.describe BaseDrop do
  let(:photo) do
    Photo.new(human_name: "test-photo", alt_text: "Vespers", version: 1,
              content_type: "image/png", data: "x", byte_size: 1, sha256: "x")
  end

  def render(source, revision)
    Current.revision = revision
    template = Liquid::Template.parse(source)
    [template.render("photo" => PhotoDrop.new(photo)), template.errors.map(&:message)]
  end

  context "while editing a draft" do
    it "refuses an invented property and says what is available" do
      build_page
      _, errors = render("{{ photo.caption }}", Revision.open_sandbox)

      expect(errors.join).to match(/has no "caption"/)
      expect(errors.join).to match(/alt/)
    end

    it "leaves real properties alone" do
      build_page
      out, errors = render("{{ photo.alt }}", Revision.open_sandbox)

      expect(out).to eq("Vespers")
      expect(errors).to be_empty
    end
  end

  # A live parish website must never 500 over a typo in a template.
  context "on the published site" do
    it "stays silent about an unknown property" do
      out, errors = render("{{ photo.caption }}", test_revision)

      expect(out).to eq("")
      expect(errors).to be_empty
    end
  end

  it "guards every drop, not just the one that was caught" do
    undefended = Dir[Rails.root.join("app/drops/*_drop.rb").to_s]
                 .reject { |f| f.end_with?("base_drop.rb") }
                 .reject { |f| File.read(f).include?("< BaseDrop") }

    expect(undefended).to be_empty, "these still inherit Liquid::Drop directly: #{undefended}"
  end
end
