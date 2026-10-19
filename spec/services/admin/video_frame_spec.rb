require "rails_helper"
require "rack/test"

# Mitch has short phone videos of parish events. Putting video ON this site is
# a bad trade -- it breaks the property that a pg_dump is a complete copy, and
# YouTube does transcoding and captions for free -- but a frame out of one is an
# ordinary photograph. Google Photos shows a decent still for every clip; there
# is no reason this cannot.
RSpec.describe Admin::VideoFrame do
  # Made here rather than committed: a video fixture in a public parish repo is
  # exactly the kind of thing that turns into a photograph of somebody's
  # children.
  def a_video(seconds: 3, size: "320x240")
    out, _err, status = Open3.capture3(
      "ffmpeg", "-f", "lavfi", "-i", "testsrc=duration=#{seconds}:size=#{size}:rate=24",
      "-c:v", "libx264", "-pix_fmt", "yuv420p", "-f", "mp4",
      "-movflags", "frag_keyframe+empty_moov", "-", binmode: true
    )
    skip("ffmpeg is not installed") unless status.success?
    out
  end

  before { skip("ffmpeg is not installed") unless described_class.available? }

  it "takes a frame that is a real image" do
    frame, = described_class.call(a_video)

    expect(Admin::ImageTools.identify(frame)).to include(format: "JPEG")
  end

  it "reports the size and length of the clip" do
    _frame, facts = described_class.call(a_video(seconds: 3, size: "320x240"))

    expect(facts[:width]).to eq(320)
    expect(facts[:height]).to eq(240)
    expect(facts[:duration]).to be > 0
  end

  # A one-second clip is shorter than the window the thumbnail filter wants.
  it "still gets a frame out of a very short clip" do
    frame, = described_class.call(a_video(seconds: 1))

    expect(Admin::ImageTools.identify(frame)).to be_present
  end

  it "refuses something that is not a video" do
    expect { described_class.call("this is just text") }
      .to raise_error(described_class::Failed)
  end

  it "knows which types it will take" do
    expect(described_class.video?("video/mp4")).to be(true)
    expect(described_class.video?("video/quicktime")).to be(true)
    expect(described_class.video?("image/jpeg")).to be(false)
  end

  describe "uploading one" do
    def upload(bytes, filename, type)
      Rack::Test::UploadedFile.new(StringIO.new(bytes), type, true, original_filename: filename)
    end

    it "becomes a photograph, and says it came from a video" do
      result = Admin::PhotoIntake.call([upload(a_video, "Parish Picnic.mp4", "video/mp4")]).first

      expect(result).to be_ok
      expect(result.photo.content_type).to eq("image/jpeg")
      expect(result.from_video[:filename]).to eq("Parish Picnic.mp4")
    end

    it "keeps the clip's name, so it is obvious where the picture came from" do
      result = Admin::PhotoIntake.call([upload(a_video, "Parish Picnic.mp4", "video/mp4")]).first

      expect(result.photo.human_name).to include("parish-picnic")
      expect(result.photo.original_filename).to eq("Parish Picnic.mp4")
    end

    it "recognises a phone video by its extension when the browser says nothing useful" do
      result = Admin::PhotoIntake.call([upload(a_video, "IMG_0042.MOV", "application/octet-stream")]).first

      expect(result).to be_ok
    end

    it "takes tags like any other upload" do
      result = Admin::PhotoIntake.call([upload(a_video, "clip.mp4", "video/mp4")],
                                       tags: ["Parish Picnic"]).first

      expect(result.photo.tag_labels).to eq(["Parish Picnic"])
    end

    it "does not keep the video" do
      video = a_video
      result = Admin::PhotoIntake.call([upload(video, "clip.mp4", "video/mp4")]).first

      expect(result.photo.byte_size).to be < video.bytesize
      expect(Admin::ImageTools.identify(result.photo.data)[:format]).to eq("JPEG")
    end

    it "refuses a video with no video track, rather than storing nothing" do
      result = Admin::PhotoIntake.call([upload("not a video at all", "clip.mp4", "video/mp4")]).first

      expect(result).not_to be_ok
      expect(result.filename).to eq("clip.mp4")
    end
  end
end
