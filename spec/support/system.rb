# Browser-driven specs.
#
# Most of this suite talks to the application directly, which is faster and
# steadier. A few things cannot be tested that way at all, because they only
# exist in a browser: whether saving a field reloads the page, whether a row
# moves while somebody is typing in it, whether a button appears when it should.
#
# Those failures are invisible to a request spec -- the server does exactly the
# right thing in every case -- which is why the photo library moved under
# Mitch's hands twice before anybody could say what was wrong.
require "capybara/rspec"
require "selenium-webdriver"

# This Mac's Chrome.app contains a binary called "Google Chrome Beta", which is
# not a name Selenium looks for. CHROME overrides it, as it does for the
# editor's own browser checks.
chrome_binary = ENV["CHROME"].presence || [
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome Beta",
  "/Applications/Chromium.app/Contents/MacOS/Chromium",
  "/usr/bin/chromium", "/usr/bin/google-chrome"
].find { |p| File.executable?(p) }

Capybara.register_driver :sjoca_headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.binary = chrome_binary if chrome_binary
  options.add_argument("--headless=new")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-gpu")
  options.add_argument("--window-size=1400,1000")
  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.default_max_wait_time = 5

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :sjoca_headless_chrome }

  # A browser talks to a real server on another thread, which cannot see
  # anything still inside an uncommitted transaction.
  config.before(:each, type: :system) do
    self.use_transactional_tests = false
  end

  config.after(:each, type: :system) do
    # Order matters: blocks and sections hang off pages and revisions.
    [RevisionMessage, Block, Section, Page, Template, ThemeAsset, SiteSetting,
     DataSource, RevisionPromise, Promise, Photo, Tag, Revision, User].each(&:delete_all)
  end
end
