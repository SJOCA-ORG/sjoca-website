require "rails_helper"
require "open3"

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

# The library page pulled 200 rows out of the database to print 200 names, and
# because the picture lives in the row that meant 147 MB over the wire. On a
# laptop Postgres is the same machine and it never showed; on the server the
# page took a minute to appear.
RSpec.describe "the photo library does not fetch the pictures", type: :request do
  def a_real_jpeg
    @a_real_jpeg ||= Open3.capture3("magick", "-size", "60x40", "gradient:navy-white",
                                    "jpg:-", binmode: true).first
  end

  it "never asks the database for the data column while listing" do
    3.times do |n|
      bytes = a_real_jpeg + ("\0" * n)   # same picture, different bytes, so each is its own
      Photo.create!(human_name: "listing-#{n}", data: bytes, content_type: "image/jpeg",
                    byte_size: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes),
                    status: "published")
    end

    selects = []
    listener = ->(_n, _s, _f, _i, payload) { selects << payload[:sql] }

    ActiveSupport::Notifications.subscribed(listener, "sql.active_record") do
      get "/admin/photos"
    end

    expect(response).to have_http_status(:ok)

    guilty = selects.select { |q| q =~ /SELECT/i && q =~ /FROM "photos"/i && q =~ /"photos"\."data"/ }
    expect(guilty).to be_empty,
      -> { "the library asked for image bytes:\n  " + guilty.first.to_s[0, 160] }
  end

  # And the scope has to actually be a scope, not a comment.
  it "raises rather than quietly returning nothing if the bytes are asked for" do
    bytes = a_real_jpeg
    Photo.create!(human_name: "listing-x", data: bytes, content_type: "image/jpeg",
                  byte_size: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes),
                  status: "published")

    expect { Photo.published.listing.first.data }
      .to raise_error(ActiveModel::MissingAttributeError)
  end
end

# The order is chosen, and stays chosen while you work.
#
# It used to be fixed, and saving a name reloaded the page -- so the row you had
# just renamed jumped somewhere else while you were still typing its tags, and
# you carried on typing into a different photograph.
RSpec.describe "the order of the photo library", type: :request do
  it "is by date added unless asked otherwise" do
    get "/admin/photos"

    expect(response.body).to include("date added")
    expect(response.body).to match(/class="sort-link is-on"[^>]*>\s*date added/m)
  end

  it "can be by name, and says so" do
    get "/admin/photos?order=name"

    expect(response.body).to match(/class="sort-link is-on"[^>]*>\s*name/m)
  end

  it "ignores an order nobody offered" do
    get "/admin/photos?order=; DROP TABLE photos"

    expect(response).to have_http_status(:ok)
    expect(response.body).to match(/class="sort-link is-on"[^>]*>\s*date added/m)
  end

  it "keeps the filter and the search when the order changes" do
    get "/admin/photos?tag=clergy&q=david&order=name"

    expect(response.body).to include("tag=clergy")
    expect(response.body).to include("q=david")
  end

  # The save that does not reload the page needs an answer a script can read.
  def a_photo
    bytes = Open3.capture3("magick", "-size", "40x30", "gradient:navy-white",
                           "jpg:-", binmode: true).first
    Photo.create!(human_name: "orderable", data: bytes, content_type: "image/jpeg",
                  byte_size: bytes.bytesize, sha256: Digest::SHA256.hexdigest(bytes),
                  status: "published")
  end

  it "answers a rename with JSON when a script asks" do
    photo = a_photo
    patch "/admin/photos/#{photo.id}",
          params: { human_name: "renamed-by-a-spec" },
          headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)["name"]).to eq("renamed-by-a-spec")
  end

  # "Not A Slug!" is fine -- it is canonicalised. A name with nothing in it that
  # could BE a name is not.
  it "answers a bad rename with JSON too, rather than redirecting" do
    photo = a_photo
    patch "/admin/photos/#{photo.id}",
          params: { human_name: "!!!" },
          headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body)["ok"]).to be(false)
  end
end
