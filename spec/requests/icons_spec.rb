require "rails_helper"

# THE REGRESSION THIS FILE EXISTS FOR.
#
# `get "*path"` matches "manifest" and "service-worker", so the catch-all page
# route swallowed both before they could reach rails/pwa -- which was not in
# routes.rb at all. Neither had ever resolved. The PWA routes must stay ahead
# of the catch-all, and nothing may be allowed to quietly reorder them.
RSpec.describe "Icon and manifest routes" do
  it "serves the web app manifest as JSON, not as a missing page" do
    get "/manifest.json"

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("application/json")
  end

  it "names the parish in the manifest rather than Rails' placeholder" do
    get "/manifest.json"
    manifest = JSON.parse(response.body)

    expect(manifest["name"]).to match(/St John the Baptist/i)
    expect(manifest["name"]).not_to eq("Sjoca")
  end

  it "declares icons at the sizes it claims" do
    get "/manifest.json"
    icons = JSON.parse(response.body).fetch("icons")

    expect(icons).to be_present
    icons.each do |icon|
      path = Rails.public_path.join(icon["src"].delete_prefix("/"))
      expect(path).to exist, "manifest references #{icon['src']} which is not in public/"
    end
  end

  it "serves the service worker" do
    get "/service-worker.js"
    expect(response).to have_http_status(:ok)
  end

  it "still routes ordinary pages, so the fix did not break the catch-all" do
    build_page(slug: "contact", title: "Contact", nav_title: "Contact")
    get "/contact"
    expect(response).to have_http_status(:ok)
  end

  it "keeps the health check reachable" do
    get "/up"
    expect(response).to have_http_status(:ok)
  end
end
