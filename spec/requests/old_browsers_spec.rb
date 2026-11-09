require "rails_helper"

# A parish website is read on whatever phone somebody already owns.
#
# Rails 8 scaffolds `allow_browser versions: :modern` into ApplicationController.
# It shipped here unexamined, and for five weeks every visitor on Safari below
# 17.2 was answered with 406 and "Your browser is not supported" -- including
# anyone with an iPhone 8 or X, which cannot run iOS 17 at any version. The site
# was not degraded for them. It was unreachable.
#
# It was found hours after the domain cutover, by accident, because a headless
# browser taking a phone screenshot called itself Safari 17.0. Nobody reports a
# website that tells them to upgrade their phone; they just stop coming. So the
# check has to be automatic.
RSpec.describe "Visitors on older browsers" do
  before do
    home = build_page(slug: "home", title: "Home", nav_title: "Home", position: 1)
    section = build_section(page: home, style: "plain")
    build_block(section: section, kind: "heading", content: "Service Times")
  end

  # Real strings. A version number invented for a test proves only that the test
  # agrees with itself.
  AGENTS = {
    "iPhone, iOS 17.0" =>
      "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " \
      "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
    "iPhone 8, iOS 16.7 — cannot run iOS 17 at all" =>
      "Mozilla/5.0 (iPhone; CPU iPhone OS 16_7 like Mac OS X) AppleWebKit/605.1.15 " \
      "(KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1",
    "iPad, iPadOS 15.6" =>
      "Mozilla/5.0 (iPad; CPU OS 15_6 like Mac OS X) AppleWebKit/605.1.15 " \
      "(KHTML, like Gecko) Version/15.6 Mobile/15E148 Safari/604.1",
    "Mac, Safari 16.1" =>
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " \
      "(KHTML, like Gecko) Version/16.1 Safari/605.1.15",
    "Android, older Chrome" =>
      "Mozilla/5.0 (Linux; Android 10; SM-G960F) AppleWebKit/537.36 " \
      "(KHTML, like Gecko) Chrome/100.0.0.0 Mobile Safari/537.36",
    "current iPhone" =>
      "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 " \
      "(KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1"
  }.freeze

  AGENTS.each do |who, agent|
    it "serves the home page to #{who}" do
      get "/", headers: { "HTTP_USER_AGENT" => agent }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Service Times")
      expect(response.body).not_to include("Your browser is not supported")
    end
  end

  # The guard above only holds while nobody adds the line back, and the natural
  # way to add it back is to let a Rails upgrade re-scaffold it.
  it "has no allow_browser anywhere in app/" do
    offenders = Dir[Rails.root.join("app/**/*.rb")].select do |f|
      File.read(f).match?(/^\s*allow_browser/)
    end

    expect(offenders).to be_empty,
      "allow_browser is back in #{offenders.map { |f| f.sub("#{Rails.root}/", '') }.join(', ')}. " \
      "It answers older browsers with 406. See the comment in ApplicationController."
  end
end
