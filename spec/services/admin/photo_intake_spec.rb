require "rails_helper"
require "rack/test"

# Twenty-six photographs already in this database carried EXIF and eight
# carried GPS, including clergy portraits the deployed site serves to anyone
# who downloads them. Nobody decided to publish coordinates; it simply
# happened, one upload at a time. These specs are the thing that stops it
# happening again.
RSpec.describe Admin::PhotoIntake do
  def a_real_jpeg(bytes: nil)
    bytes || Admin::ImageTools.strip(fixture_photo, "jpg")
  end

  # A genuine image, made here rather than committed: parish photographs do not
  # go in this repo.
  def fixture_photo
    @fixture_photo ||= begin
      out, _err, _status = Open3.capture3(
        "magick", "-size", "120x90", "gradient:navy-white", "jpg:-", binmode: true
      )
      out
    end
  end

  # A second, visibly different picture, for the cases that turn on the bytes
  # rather than on the filename.
  def another_photo
    @another_photo ||= begin
      out, _err, _status = Open3.capture3(
        "magick", "-size", "120x90", "gradient:darkgreen-yellow", "jpg:-", binmode: true
      )
      out
    end
  end

  def upload(bytes, filename:, type: "image/jpeg")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), type, true, original_filename: filename)
  end

  def take(bytes, filename: "IMG_0001.JPG", **opts)
    described_class.call([upload(bytes, filename: filename)], **opts).first
  end

  # A phone takes 4000x3000 at six or seven megabytes and the site never draws a
  # picture wider than about 1280. Two hundred and sixty arrived at full size and
  # made a 400MB database out of what should have been about fifty.
  describe "size" do
    def a_large_jpeg
      out, _e, _s = Open3.capture3("magick", "-size", "4000x3000", "gradient:navy-white",
                                   "jpg:-", binmode: true)
      out
    end

    it "shrinks a photograph bigger than the site can ever show" do
      photo = take(a_large_jpeg, filename: "PXL_0001.jpg").photo
      info = Admin::ImageTools.identify(photo.data)

      expect([info[:width], info[:height]].max).to eq(2000)
    end

    # Only ever shrink. Blowing a small picture up produces a larger, blurrier
    # one and helps nobody.
    it "leaves a small photograph exactly as it is" do
      small, _e, _s = Open3.capture3("magick", "-size", "300x200", "gradient:red-white",
                                     "jpg:-", binmode: true)
      photo = take(small, filename: "small.jpg").photo
      info = Admin::ImageTools.identify(photo.data)

      expect([info[:width], info[:height]]).to eq([300, 200])
    end
  end

  describe "metadata" do
    it "removes EXIF before the bytes are ever stored" do
      with_exif, _e, _s = Open3.capture3(
        "magick", "-", "-set", "exif:DateTimeOriginal", "2026:03:01 18:35:12", "jpg:-",
        stdin_data: fixture_photo, binmode: true
      )
      result = take(with_exif)

      expect(result).to be_ok
      expect(Admin::ImageTools.identify(result.photo.data)).to be_present
      stored = Tempfile.new(["p", ".jpg"]).tap { |f| f.binmode; f.write(result.photo.data); f.close }
      expect(`magick identify -format "%[EXIF:*]" #{stored.path} 2>/dev/null`).to be_blank
    end
  end

  describe "what it refuses" do
    it "refuses something that is not an image, whatever it is called" do
      result = take("this is just text, renamed", filename: "sneaky.jpg")

      expect(result).not_to be_ok
      expect(result.error).to match(/not really an image/)
    end

    it "refuses a type the site cannot show" do
      result = described_class.call([upload("%PDF-1.4", filename: "parish.pdf", type: "application/pdf")]).first

      expect(result).not_to be_ok
      expect(result.error).to match(/not an image/)
    end

    it "refuses an empty file" do
      expect(take("", filename: "nothing.jpg")).not_to be_ok
    end

    it "reports the filename with the refusal, so a person knows which one" do
      result = take("nope", filename: "aunt-marys-cake.jpg")

      expect(result.filename).to eq("aunt-marys-cake.jpg")
    end

    it "takes the good ones and reports the bad, rather than failing the batch" do
      results = described_class.call([
        upload(a_real_jpeg, filename: "good.jpg"),
        upload("rubbish", filename: "bad.jpg")
      ])

      expect(results.count(&:ok?)).to eq(1)
      expect(results.reject(&:ok?).first.filename).to eq("bad.jpg")
    end
  end

  describe "naming" do
    it "gives a provisional name marked as one" do
      expect(take(a_real_jpeg, filename: "IMG_4821.JPG").photo.human_name).to eq("new-img-4821")
    end

    # Two DIFFERENT photographs both called IMG_4821 are not the same subject,
    # so this must never become a new VERSION of the first.
    it "keeps two different pictures with the same filename apart" do
      first = take(a_real_jpeg, filename: "IMG_4821.JPG")
      second = take(a_real_jpeg(bytes: Admin::ImageTools.strip(another_photo, "jpg")),
                    filename: "IMG_4821.JPG")

      expect(second.photo.human_name).not_to eq(first.photo.human_name)
      expect(second.photo.human_name).to match(/\Anew-img-4821-\d+\z/)
    end

    # The other half of that rule, and the one that cost us. The same bytes are
    # the same photograph whatever the file was called, so a form submitted
    # twice must not make a second copy under a -2 name. Fifty-four pictures
    # sent five times became 270 rows and 270 queued description jobs.
    it "returns the photograph already held rather than copying it" do
      first = take(a_real_jpeg, filename: "IMG_4821.JPG")
      second = take(a_real_jpeg, filename: "something-else.jpg")

      expect(second.photo.id).to eq(first.photo.id)
      expect(second.already_here).to be(true)
      expect(Photo.count).to eq(1)
    end

    it "still applies new tags to a photograph that was already held" do
      take(a_real_jpeg, filename: "IMG_4821.JPG", tags: ["choir"])
      again = take(a_real_jpeg, filename: "IMG_4821.JPG", tags: ["pascha 2026"])

      expect(again.photo.reload.tags.map(&:name)).to include("choir", "pascha-2026")
    end

    it "copes with a filename that has nothing usable in it" do
      expect(take(a_real_jpeg, filename: "....jpg").photo.human_name).to start_with("new-upload")
    end
  end

  it "records when it arrived and what it was called" do
    photo = take(a_real_jpeg, filename: "IMG_0007.JPG").photo

    expect(photo.uploaded_at).to be_present
    expect(photo.original_filename).to eq("IMG_0007.JPG")
    expect(Photo.recently_uploaded).to include(photo)
  end

  # Told this was fixed once and it was not: the edit was lost when a later
  # assertion in the same block failed before the file was written. Tags were
  # arriving as one string -- "Parish Picnic, outreach" was a single tag -- for
  # a day after it was reported fixed.
  describe "tags as a person types them" do
    it "splits one field holding several" do
      expect(described_class.tags_from(["Parish Picnic, outreach"]))
        .to eq(["Parish Picnic", "outreach"])
    end

    it "splits a typed entry inside the array the menu sends" do
      expect(described_class.tags_from(["clergy", "Pascha 2026, feast days"]))
        .to eq(["clergy", "Pascha 2026", "feast days"])
    end

    it "takes a plain string too" do
      expect(described_class.tags_from("clergy, outreach")).to eq(%w[clergy outreach])
    end

    it "drops blanks and repeats" do
      expect(described_class.tags_from(["clergy", "clergy, , outreach"]))
        .to eq(%w[clergy outreach])
    end

    it "reaches a photograph through the upload" do
      photo = take(a_real_jpeg, tags: described_class.tags_from(["clergy, Feast Days"])).photo

      expect(photo.tag_labels).to contain_exactly("clergy", "Feast Days")
    end
  end

  it "applies the tags the batch was given" do
    photo = take(a_real_jpeg, tags: ["Feast Days", "clergy"]).photo

    expect(photo.tag_labels).to contain_exactly("clergy", "Feast Days")
  end

  it "leaves alt text empty, for the job that can see the picture" do
    expect(take(a_real_jpeg).photo.alt_text).to be_nil
  end
end
