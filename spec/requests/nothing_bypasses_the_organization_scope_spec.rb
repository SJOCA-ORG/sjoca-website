require "rails_helper"

# The assumption the whole design rests on, written down as a test.
#
# Organization scoping is a default_scope. That buys something large: 67 admin
# tools, a Liquid renderer, a photo library and a dozen controllers are scoped
# without any of them being audited, because the filter sits under all of them.
#
# It buys it on one condition -- that nothing reaches past ActiveRecord. One
# `find_by_sql`, one `unscoped`, and that line is reading every organization's
# rows while looking exactly like every other line in the file.
#
# When this was written, app/ contained no such call. This spec is here so that
# stays a fact rather than a memory, and so that adding one is a conversation
# in a pull request instead of a surprise in a year.
RSpec.describe "nothing bypasses the organization scope" do
  # Each pattern, and the files allowed to contain it. A file earns its place
  # here by being the mechanism itself, not by being inconvenient to change.
  FORBIDDEN = {
    /\bunscoped\b/ => [
      # Rails' own uniqueness validator calls unscoped internally; this spec
      # only reads our source, so nothing is allowed here at all.
    ],
    /\bfind_by_sql\b/      => [],
    /\bexec_query\b/       => [],
    /connection\.execute/  => [],
    /\bdefault_scope\b/    => ["app/models/concerns/belongs_to_organization.rb"],
    # Changing which organization is current is the one operation that can
    # hand one organization's data to another's request.
    /Current\.organization\s*=/ => [
      "app/models/organization.rb",                        # acting_as
      "app/models/current.rb",                             # the sole-tenant fallback
      "app/controllers/concerns/organization_scoped.rb"    # resolving the hostname
    ],
    /Organization\.acting_as/ => ["app/models/organization.rb"]
  }.freeze

  def code_lines(path)
    File.readlines(path).each_with_index.reject do |line, _|
      s = line.strip
      s.empty? || s.start_with?("#", "//", "*")
    end
  end

  def ruby_files
    Dir[Rails.root.join("app/**/*.rb")].map { |f| Pathname(f).relative_path_from(Rails.root).to_s }
  end

  it "has files to check" do
    expect(ruby_files.size).to be > 20
  end

  FORBIDDEN.each do |pattern, allowed|
    it "finds no #{pattern.source} outside #{allowed.empty? ? 'anywhere' : allowed.join(', ')}" do
      offences = ruby_files.reject { |f| allowed.include?(f) }.flat_map do |file|
        code_lines(Rails.root.join(file)).filter_map do |line, i|
          "#{file}:#{i + 1}  #{line.strip}" if line =~ pattern
        end
      end

      expect(offences).to be_empty, <<~MSG
        #{offences.size} line(s) can see past the organization scope:

          #{offences.join("\n          ")}

        Organization scoping is a default_scope, and a default_scope is only as
        good as the code that does not step around it. If one of these is
        genuinely necessary, add the file to FORBIDDEN in this spec with a
        sentence saying why -- so the exception is reviewed once rather than
        discovered later.
      MSG
    end
  end

  # The other half: a scoped model with no organization returns nothing. Proven
  # here against the real classes rather than asserted in a comment.
  it "returns nothing at all when no organization is current" do
    allow(Organization).to receive(:sole_tenant).and_return(nil)
    Current.organization = nil

    expect(Revision.count).to eq(0)
    expect(Photo.count).to eq(0)
    expect(Tag.count).to eq(0)
    expect(Revision.live).to be_nil
  end
end
