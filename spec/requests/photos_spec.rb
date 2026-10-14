require "rails_helper"

RSpec.describe "Serving images from the database" do
  let!(:asset) { build_asset(human_name: "home-hero", bytes: "PNGBYTES") }

  it "serves the current bytes with the right content type" do
    get "/media/home-hero"

    expect(response).to have_http_status(:ok)
    expect(response.body).to eq("PNGBYTES")
    expect(response.media_type).to eq("image/png")
  end

  it "404s for an unknown name" do
    get "/media/no-such-image"
    expect(response).to have_http_status(:not_found)
  end

  # THE REGRESSION THIS FILE EXISTS FOR.
  #
  # `stale?` issues the 304 itself when it returns false. An earlier version
  # also called `head :not_modified`, which renders twice and raises
  # DoubleRenderError -- a 500 on *every conditional request*. The symptom was
  # baffling from the outside: the image loaded once, broke on reload, and came
  # back on back-navigation, because only the revalidating request failed.
  describe "conditional requests" do
    it "returns 304, not 500, when the ETag matches" do
      get "/media/home-hero"
      etag = response.headers["ETag"]
      expect(etag).to be_present

      get "/media/home-hero", headers: { "If-None-Match" => etag }

      expect(response).to have_http_status(:not_modified)
    end

    it "survives being revalidated repeatedly" do
      get "/media/home-hero"
      etag = response.headers["ETag"]

      3.times do
        get "/media/home-hero", headers: { "If-None-Match" => etag }
        expect(response).to have_http_status(:not_modified)
      end
    end

    it "sends fresh bytes once the asset is replaced" do
      get "/media/home-hero"
      etag = response.headers["ETag"]

      build_asset(human_name: "home-hero", bytes: "NEWBYTES", created_at: 1.minute.from_now)

      get "/media/home-hero", headers: { "If-None-Match" => etag }

      expect(response).to have_http_status(:ok)
      expect(response.body).to eq("NEWBYTES")
    end
  end

  it "keeps a stable URL while the content behind it changes" do
    build_asset(human_name: "home-hero", bytes: "REPLACED", created_at: 1.minute.from_now)

    get "/media/home-hero"

    expect(response.body).to eq("REPLACED")
  end

  it "does not serve a draft" do
    build_asset(human_name: "pending", bytes: "DRAFT", status: "draft")
    get "/media/pending"
    expect(response).to have_http_status(:not_found)
  end
end
