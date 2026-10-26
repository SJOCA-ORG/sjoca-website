require "open3"
require "tmpdir"

module Admin
  # Image processing the AI may perform.
  #
  # The rule is not "the AI may not run programs". It is: the AI may run three
  # known programs, with validated arguments, on files it cannot name, in a
  # directory it cannot leave. Four things make that true:
  #
  #   1. NO SHELL. Processes are spawned with an argv array, so there is no
  #      shell to inject into -- no quoting bugs, no ";", no backticks.
  #   2. NO PATHS. The AI names *photographs* and *operations*. Paths are ours;
  #      it cannot express one, so it cannot traverse one.
  #   3. NO NETWORK. ImageMagick will read https:// as an input file. The policy
  #      in config/imagemagick/policy.xml refuses that, along with the delegates
  #      and coders behind the ImageTragick family of bugs.
  #   4. NO RUNAWAY. Wall-clock timeout, output size cap, and resource limits in
  #      the same policy file.
  #
  # Output is always a NEW photo row. Nothing is overwritten, so an unfortunate
  # crop is undone by publishing the previous version.
  class ImageTools
    class ToolError < StandardError; end

    BINARIES = { magick: "magick", rsvg: "rsvg-convert", potrace: "potrace" }.freeze
    TIMEOUT  = 45
    MAX_BYTES = 25.megabytes
    NAME = /\A[a-z0-9][a-z0-9-]{0,80}\z/
    FORMATS = %w[png jpg jpeg webp gif].freeze
    GRAVITIES = %w[center north south east west northwest northeast southwest southeast].freeze

    def initialize(revision) = @revision = revision

    # Scale a file on disk down to fit a geometry, returning PNG bytes. Used for
    # the browser-check screenshots, which are not photos and never become rows,
    # so this is the one operation that takes a path instead of a photo name. It
    # goes through the same hardened policy as everything else here.
    # What an image actually IS, read off the bytes rather than trusted from
    # whatever the browser claimed. A file renamed to .jpg is not a jpg.
    def self.identify(bytes)
      env = { "MAGICK_CONFIGURE_PATH" => Rails.root.join("config/imagemagick").to_s }
      out, _err, status = Open3.capture3(env, BINARIES[:magick], "-", "-format", "%w %h %m",
                                         "info:", stdin_data: bytes, binmode: true)
      return nil unless status&.success?

      w, h, format = out.split
      return nil if w.blank? || h.blank?

      { width: w.to_i, height: h.to_i, pixels: w.to_i * h.to_i, format: format }
    rescue StandardError
      nil
    end

    # Remove EXIF and every other profile. A phone photograph carries where it
    # was taken, to within a few metres. A parish would never decide to publish
    # the coordinates of a parishioner's house; it would simply happen.
    # The longest side a stored photograph may have.
    #
    # A phone takes 4000x3000 at six or seven megabytes. The widest this site
    # ever draws a picture is about 1280 points, so at 2000 there is room for a
    # retina screen and for someone cropping later, and nothing beyond that is
    # ever seen by anybody. Two hundred and sixty photographs arrived at full
    # size and made a 400MB database out of what should be about fifty.
    MAX_SIDE = 2000

    def self.strip(bytes, format, max_side: MAX_SIDE)
      env = { "MAGICK_CONFIGURE_PATH" => Rails.root.join("config/imagemagick").to_s }
      out, err, status = nil
      # ">" means only ever shrink. A small photograph is left exactly as it is
      # rather than being blown up into a blurry larger one.
      resize = max_side ? ["-resize", "#{max_side}x#{max_side}>"] : []
      Timeout.timeout(TIMEOUT) do
        out, err, status = Open3.capture3(env, BINARIES[:magick], "-", "-strip", *resize,
                                          "#{format}:-", stdin_data: bytes, binmode: true)
      end
      raise ToolError, "could not read that image: #{err.to_s.lines.first&.strip}" unless status&.success?

      out
    rescue Timeout::Error
      raise ToolError, "that image took too long to process and was stopped"
    end

    # The same, for bytes already in hand rather than a file on disk.
    def self.fit_bytes(bytes, geometry)
      env = { "MAGICK_CONFIGURE_PATH" => Rails.root.join("config/imagemagick").to_s }
      out, err, status = nil
      Timeout.timeout(TIMEOUT) do
        out, err, status = Open3.capture3(env, BINARIES[:magick],
                                          "-", "-resize", geometry, "-strip", "png:-",
                                          stdin_data: bytes, binmode: true)
      end
      raise ToolError, "magick failed: #{err.to_s.lines.first&.strip}" unless status&.success?

      out
    rescue Timeout::Error
      raise ToolError, "magick took longer than #{TIMEOUT} seconds and was stopped"
    end

    def self.fit(path, geometry)
      env = { "MAGICK_CONFIGURE_PATH" => Rails.root.join("config/imagemagick").to_s }
      out, err, status = nil
      Timeout.timeout(TIMEOUT) do
        out, err, status = Open3.capture3(env, BINARIES[:magick],
                                          path, "-resize", geometry, "-strip", "png:-",
                                          binmode: true)
      end
      raise ToolError, "magick failed: #{err.to_s.lines.first&.strip}" unless status&.success?

      out
    rescue Timeout::Error
      raise ToolError, "magick took longer than #{TIMEOUT} seconds and was stopped"
    end

    # ---- operations --------------------------------------------------------

    def describe(name:)
      photo = fetch(name)
      out = run_capture(BINARIES[:magick], ["-", "-format", "%wx%h %m %[size]", "info:"], photo.data)
      w, h = out.split.first.to_s.split("x")
      { name: name, width: w.to_i, height: h.to_i, format: out.split[1],
        bytes: photo.byte_size, content_type: photo.content_type }
    end

    def crop(name:, x:, y:, width:, height:, as:)
      transform(name, as, ["-crop", "#{int(width)}x#{int(height)}+#{int(x)}+#{int(y)}", "+repage"],
                "cropped #{name} to #{int(width)}x#{int(height)}")
    end

    def resize(name:, as:, width: nil, height: nil)
      geom = "#{width ? int(width) : ''}x#{height ? int(height) : ''}"
      raise ToolError, "give a width, a height, or both" if geom == "x"

      transform(name, as, ["-resize", geom], "resized #{name} to #{geom}")
    end

    def rotate(name:, degrees:, as:)
      transform(name, as, ["-rotate", int(degrees).to_s], "rotated #{name} by #{int(degrees)}°")
    end

    def trim(name:, as:)
      transform(name, as, ["-trim", "+repage"], "trimmed the blank edges from #{name}")
    end

    # brightness/saturation/hue are percentages, 100 meaning unchanged.
    def adjust(name:, as:, brightness: 100, saturation: 100, hue: 100)
      transform(name, as,
                ["-modulate", "#{int(brightness)},#{int(saturation)},#{int(hue)}"],
                "adjusted #{name} (brightness #{int(brightness)}%, saturation #{int(saturation)}%)")
    end

    def grayscale(name:, as:)
      transform(name, as, ["-colorspace", "Gray"], "converted #{name} to black and white")
    end

    # A soft vignette so a photograph sits on the page without a hard edge.
    def feather_edges(name:, as:, radius: 24)
      r = int(radius).clamp(1, 200)
      transform(name, as,
                ["-alpha", "set", "-virtual-pixel", "transparent",
                 "-channel", "A", "-blur", "0x#{r}", "-level", "50%,100%", "+channel"],
                "feathered the edges of #{name}", format: "png")
    end

    def round_corners(name:, as:, radius: 24)
      r = int(radius).clamp(1, 400)
      transform(name, as,
                ["-alpha", "set", "(", "+clone", "-alpha", "extract",
                 "-draw", "fill black polygon 0,0 0,#{r} #{r},0 fill white circle #{r},#{r} #{r},0",
                 "(", "+clone", "-flip", ")", "-compose", "Multiply", "-composite",
                 "(", "+clone", "-flop", ")", "-compose", "Multiply", "-composite", ")",
                 "-alpha", "off", "-compose", "CopyOpacity", "-composite"],
                "rounded the corners of #{name}", format: "png")
    end

    def convert(name:, format:, as:)
      fmt = format.to_s.downcase
      raise ToolError, "format must be one of #{FORMATS.join(', ')}" unless FORMATS.include?(fmt)

      transform(name, as, [], "converted #{name} to #{fmt}", format: fmt)
    end

    def composite(base:, overlay:, as:, gravity: "center")
      raise ToolError, "gravity must be one of #{GRAVITIES.join(', ')}" unless GRAVITIES.include?(gravity.to_s)

      check_name(as)
      under, over = fetch(base), fetch(overlay)
      Dir.mktmpdir("sjoca-img") do |dir|
        a = write(dir, "base", under)
        b = write(dir, "over", over)
        out = File.join(dir, "out.png")
        run(BINARIES[:magick], [a, b, "-gravity", gravity.to_s, "-composite", out])
        store(as, File.read(out, mode: "rb"), "image/png",
              "placed #{overlay} over #{base}")
      end
    end

    private

    def int(v)
      Integer(v)
    rescue ArgumentError, TypeError
      raise ToolError, "#{v.inspect} is not a whole number"
    end

    def fetch(name)
      Photo.newest(name) || raise(ToolError, "there is no photograph called #{name.inspect}")
    end

    def check_name(name)
      raise ToolError, "#{name.inspect} is not a usable name (letters, numbers and hyphens)" unless NAME.match?(name.to_s)
      name.to_s
    end

    def extension(photo) = photo.content_type.to_s.split("/").last.sub("jpeg", "jpg").presence || "png"

    def write(dir, stem, photo)
      path = File.join(dir, "#{stem}.#{extension(photo)}")
      File.binwrite(path, photo.data)
      path
    end

    def transform(name, as, ops, summary, format: nil)
      check_name(as)          # before spawning anything, not after
      photo = fetch(name)
      Dir.mktmpdir("sjoca-img") do |dir|
        input = write(dir, "in", photo)
        ext   = format || extension(photo)
        out   = File.join(dir, "out.#{ext}")
        run(BINARIES[:magick], [input, *ops, out])
        bytes = File.read(out, mode: "rb")
        store(as, bytes, "image/#{ext == 'jpg' ? 'jpeg' : ext}", summary)
      end
    end

    def store(as, bytes, content_type, summary)
      name = check_name(as)
      raise ToolError, "the result is #{bytes.bytesize} bytes, over the #{MAX_BYTES} limit" if bytes.bytesize > MAX_BYTES
      raise ToolError, "the operation produced nothing" if bytes.empty?

      # Stamped with the revision that produced it, so a reference can pin it and
      # rolling back restores the picture along with the words.
      photo = Photo.create!(human_name: name, data: bytes, byte_size: bytes.bytesize,
                            content_type: content_type, sha256: Photo.digest(bytes),
                            status: "published", version: @revision.id)
      { ok: true, summary: "#{summary}, saved as #{name} (version #{photo.version})",
        photo: name, version: photo.version, bytes: photo.byte_size }
    rescue ActiveRecord::RecordInvalid => e
      raise ToolError, e.record.errors.full_messages.to_sentence
    end

    # No shell, ever. An argv array goes straight to execve.
    def run(binary, args, stdin = nil)
      env = { "MAGICK_CONFIGURE_PATH" => Rails.root.join("config/imagemagick").to_s }
      out, err, status = nil

      Timeout.timeout(TIMEOUT) do
        out, err, status = Open3.capture3(env, binary, *args, stdin_data: stdin.to_s, binmode: true)
      end

      raise ToolError, "#{binary} failed: #{err.to_s.lines.first&.strip}" unless status&.success?

      out
    rescue Timeout::Error
      raise ToolError, "#{binary} took longer than #{TIMEOUT} seconds and was stopped"
    rescue Errno::ENOENT
      raise ToolError, "#{binary} is not installed on this server"
    end

    def run_capture(binary, args, stdin) = run(binary, args, stdin)
  end
end
