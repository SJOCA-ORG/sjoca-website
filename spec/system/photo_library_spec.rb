require "rails_helper"
require "open3"

# THE BUG THIS FILE EXISTS FOR.
#
# Mitch, twice: "It jumps around a lot after typing. For example I added a name
# to a recently uploaded icon, and after moving the focus the icon jumped, but
# it took a second and I was already typing the tags."
#
# Saving a name submitted the form, the page reloaded, the list re-sorted, and
# the row being edited moved somewhere else — so the next thing typed went into
# a different photograph. Every request spec passed throughout: the server did
# exactly the right thing each time. Only a browser can see this.
RSpec.describe "the photo library", type: :system do
  let(:password) { "Parish-Test-24" }

  def a_jpeg(seed)
    Open3.capture3("magick", "-size", "40x30", "gradient:navy-white", "jpg:-",
                   binmode: true).first + ("\0" * seed)
  end

  def photo(name, uploaded:)
    bytes = a_jpeg(name.length)
    Photo.create!(human_name: name, data: bytes, content_type: "image/jpeg",
                  byte_size: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes),
                  status: "published", uploaded_at: uploaded, alt_text: "A test photograph")
  end

  before do
    User.create!(email: "editor@example.com", password: password, role: "superadmin")

    # Named so that the two orders are DIFFERENT: by date the zebra is first,
    # by name the apple is. A spec that cannot tell them apart proves nothing.
    photo("zebra-newest", uploaded: 1.hour.ago)
    photo("apple-oldest", uploaded: 3.days.ago)

    visit "/admin/login"
    fill_in "session[email]", with: "editor@example.com"
    fill_in "session[password]", with: password
    click_button "Sign in"
    # Wait for it to LAND. Navigating while the sign-in is still in flight means
    # the pending redirect arrives afterwards and overwrites wherever you went.
    expect(page).to have_current_path("/admin", wait: 5)

    visit "/admin/photos"
    expect(page).to have_css(".shot", wait: 5)
  end

  # The FULL library, not the "Just added" strip above it. That strip is always
  # newest-first by design, and reading both made the spec report an order the
  # page was not in.
  def names_in_order
    within("#all-photos") { all(".shot input.name-field").map(&:value) }
  end

  def library_fields
    within("#all-photos") { all(".shot input.name-field") }
  end

  it "shows the newest first to begin with" do
    expect(names_in_order.first).to eq("zebra-newest")
  end

  it "sorts by name when asked, and says which order it is in" do
    click_link "name"

    # Wait for the NEW page before reading the order off it. Capybara's click
    # returns as soon as the click lands, not when the navigation finishes, so
    # reading immediately reads the page you just left.
    expect(page).to have_css(".sort-link.is-on", text: "name", wait: 5)

    expect(names_in_order.first).to eq("apple-oldest")
  end

  describe "renaming something" do
    it "does not move it" do
      before_order = names_in_order
      field = library_fields.last                     # the one that WOULD move

      field.set("aaa-would-sort-first")
      find("body").click                              # move the focus away

      expect(page).to have_css(".shot.saved", wait: 5)

      # The row is still where it was. Under the old behaviour the page would
      # have reloaded and this photograph would now be first.
      expect(names_in_order.last).to eq("aaa-would-sort-first")
      expect(names_in_order.length).to eq(before_order.length)
    end

    it "saves it, without the page reloading" do
      page.execute_script("window.__stillHere = true")

      field = library_fields.first
      field.set("renamed-in-a-browser")
      find("body").click

      expect(page).to have_css(".shot.saved", wait: 5)
      expect(page.evaluate_script("window.__stillHere")).to be(true)
      expect(Photo.exists?(human_name: "renamed-in-a-browser")).to be(true)
    end

    # In NAME order, so that renaming genuinely changes where the row belongs.
    # In date-added order it does not -- renaming a photograph does not change
    # when it arrived -- and a spec that cannot tell proves nothing.
    it "offers to put the list back in order, once there is a reason to" do
      click_link "name"
      expect(page).to have_css(".sort-link.is-on", text: "name", wait: 5)
      expect(page).not_to have_css("#resort", visible: true)

      expect(names_in_order.last).to eq("zebra-newest")
      library_fields.last.set("aaa-would-sort-first")
      find("body").click

      expect(page).to have_css(".shot.saved", wait: 5)
      expect(page).to have_css("#resort", visible: true, wait: 5)

      # Still last. The list did NOT reorder itself while the editing happened.
      expect(names_in_order.last).to eq("aaa-would-sort-first")

      click_link "put back in order"
      expect(page).to have_css("#all-photos .shot", wait: 5)
      expect(page).to have_no_css("#resort", visible: true, wait: 5)

      # And now it has, because it was asked to.
      expect(names_in_order.first).to eq("aaa-would-sort-first")
    end

    it "says so, on the card, when a name cannot be saved" do
      library_fields.first.set("!!!")
      find("body").click

      expect(page).to have_css(".shot.save-failed", wait: 5)
      expect(page).to have_css(".save-error", wait: 5)
      expect(find(".save-error").text).to be_present
    end
  end
end
