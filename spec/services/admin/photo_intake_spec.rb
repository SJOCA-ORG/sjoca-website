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

  def upload(bytes, filename:, type: "image/jpeg")
    Rack::Test::UploadedFile.new(StringIO.new(bytes), type, true, original_filename: filename)
  end

  def take(bytes, filename: "IMG_0001.JPG", **opts)
    described_class.call([upload(bytes, filename: filename)], **opts).first
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

    # Two photographs called IMG_4821 are not the same subject, so this must
    # never become a new VERSION of the first.
    it "keeps two uploads of the same filename apart" do
      first = take(a_real_jpeg, filename: "IMG_4821.JPG")
      second = take(a_real_jpeg, filename: "IMG_4821.JPG")

      expect(second.photo.human_name).not_to eq(first.photo.human_name)
      expect(second.photo.human_name).to match(/\Anew-img-4821-\d+\z/)
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

  it "applies the tags the batch was given" do
    photo = take(a_real_jpeg, tags: ["Feast Days", "clergy"]).photo

    expect(photo.tag_labels).to contain_exactly("clergy", "Feast Days")
  end

  it "leaves alt text empty, for the job that can see the picture" do
    expect(take(a_real_jpeg).photo.alt_text).to be_nil
  end
end
