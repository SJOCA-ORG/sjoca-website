require "rails_helper"

# A photo reference is a PAIR -- the name and the version -- and that pair is
# what makes a rollback honest: a page says exactly which image it meant.
#
# Nothing enforced it. Three different photographs were all
# "leadership-dn-mitch version 1": an ordination, and two at the altar.
# find_version does a find_by, so the pair resolved to whichever row Postgres
# returned first -- the DEPLOYED site showed one and a developer machine showed
# another, from the identical reference.
RSpec.describe Photo, "versioning" do
  def photo(name, bytes, **attrs)
    described_class.create!(human_name: name, data: bytes, content_type: "image/png",
                            byte_size: bytes.bytesize,
                            sha256: Digest::SHA256.hexdigest(bytes), **attrs)
  end

  it "numbers versions itself, so no caller can get it wrong" do
    expect(photo("parish-picnic", "one").version).to eq(1)
    expect(photo("parish-picnic", "two").version).to eq(2)
    expect(photo("parish-picnic", "three").version).to eq(3)
  end

  it "numbers each name separately" do
    photo("a", "one")
    expect(photo("b", "two").version).to eq(1)
  end

  # The seeds set version 1 on every run, which is how three accumulated.
  it "refuses to reuse a version, even when one is handed to it" do
    photo("parish-picnic", "one")
    second = photo("parish-picnic", "two", version: 1)

    expect(second.version).to eq(2)
    expect(described_class.where(human_name: "parish-picnic", version: 1).count).to eq(1)
  end

  it "keeps a version the caller asks for when it is free" do
    expect(photo("parish-picnic", "one", version: 7).version).to eq(7)
  end

  # The model assigns versions, so the validation is hard to reach through
  # ordinary use -- which is the point. The database is the backstop for
  # anything that writes rows without going through the model: a seed, a
  # migration, a console session, an import.
  it "will not let the DATABASE hold two images at one version" do
    first = photo("parish-picnic", "one")

    expect {
      ActiveRecord::Base.connection.execute(<<~SQL)
        INSERT INTO photos (human_name, data, content_type, byte_size, sha256,
                            status, version, created_at, updated_at)
        VALUES ('parish-picnic', 'two', 'image/png', 3, 'deadbeef',
                'published', #{first.version}, now(), now())
      SQL
    }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  # The guarantee the design rests on.
  it "resolves a pair to exactly one photograph" do
    a = photo("parish-picnic", "one")
    b = photo("parish-picnic", "two")

    expect(described_class.find_version("parish-picnic", a.version)).to eq(a)
    expect(described_class.find_version("parish-picnic", b.version)).to eq(b)
  end

  it "has no duplicate pairs anywhere in the library" do
    expect(described_class.group(:human_name, :version).having("count(*) > 1").count).to be_empty
  end
end
