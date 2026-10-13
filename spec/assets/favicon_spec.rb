require "rails_helper"

# THE REGRESSION THIS FILE EXISTS FOR.
#
# The first parish mark shipped with the flower at #873131 on #212121 -- 1.93:1,
# and in a real browser tab the flower was simply not there. It looked fine at
# 512px, which is the only size anyone had looked at.
#
# The lesson is narrower than "check contrast". The mark that replaced it
# measures 2.17:1, barely better, and reads perfectly well -- because it is a
# large solid shape rather than sub-pixel line-work. Contrast ratio alone is the
# wrong instrument for a small icon. What these specs pin down is the floor
# below which *nothing* survives, plus the rule that the cross -- the one thing
# that must be legible at 16px -- is held to a much higher standard.
RSpec.describe "The parish mark" do
  ICON = Rails.public_path.join("icon.svg")

  def luminance(hex)
    channels = hex.delete("#").scan(/../).map { |c| c.to_i(16) / 255.0 }
    r, g, b = channels.map { |v| v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055)**2.4 }
    (0.2126 * r) + (0.7152 * g) + (0.0722 * b)
  end

  def contrast(a, b)
    hi, lo = [luminance(a), luminance(b)].minmax.reverse
    ((hi + 0.05) / (lo + 0.05)).round(2)
  end

  # Fills appear in painting order: ground, then flower, then cross.
  let(:fills) { ICON.read.scan(/fill="(#[0-9A-Fa-f]{6})"/).flatten }
  let(:ground) { fills[0] }
  let(:flower) { fills[1] }
  let(:cross)  { fills[2] }

  it "exists and declares exactly three colours" do
    expect(ICON).to exist
    expect(fills.uniq.size).to eq(3), "expected ground, flower and cross: #{fills.uniq}"
  end

  it "holds the cross well clear of its ground — it must read at 16px" do
    expect(contrast(cross, ground)).to be >= 4.5
  end

  it "keeps the cross distinguishable from the flower it sits on" do
    expect(contrast(cross, flower)).to be >= 3.0
  end

  # 2.0 rather than 3.0 deliberately: the shipped mark is a solid silhouette and
  # sits at 2.17. This floor still catches the 1.93:1 version that failed.
  it "keeps the flower distinguishable from its ground" do
    expect(contrast(flower, ground)).to be >= 2.0
  end

  it "draws its colours from the site's own palette" do
    stylesheet = Dir[Rails.root.join("app/assets/stylesheets/**/*.css")]
                 .map { |f| File.read(f) }.join.upcase

    [ground, cross].each do |colour|
      expect(stylesheet).to include(colour.upcase),
                            "#{colour} is not a colour the site uses anywhere else"
    end
  end

  describe "the generated files" do
    %w[favicon.ico icon.png icon-16.png icon-32.png icon-48.png
       icon-180.png icon-192.png icon-512.png icon-maskable-512.png].each do |name|
      it "ships #{name}" do
        expect(Rails.public_path.join(name)).to exist
      end
    end

    it "is linked from the layout, or the browser asks for a favicon that 404s" do
      layout = Rails.root.join("app/views/layouts/application.html.erb").read

      expect(layout).to include('rel="icon"')
      expect(layout).to include('rel="apple-touch-icon"')
      expect(layout).to include('rel="manifest"')
    end
  end
end
