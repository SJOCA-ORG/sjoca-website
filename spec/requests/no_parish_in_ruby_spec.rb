require "rails_helper"

# The test, in Mitch's words: "insure what makes this a unique website is
# totally controlled by the admin-ai via the database. Nothing in ruby side
# should know that this is a church."
#
# A second parish must be able to run this code unchanged. Anything in Ruby
# that would be WRONG for them is a fact, and belongs in the revision.
#
# This spec reads the source. That is unusual and deliberate: the failures it
# catches are not behavioural — the site works perfectly with this parish's
# name baked in, right up until somebody else installs it.
RSpec.describe "no parish is written into the code", type: :request do
  PARISH = /john the baptist|orthodox|vespers|divine liturgy|rochester|goodman|sjoca\.org|fr\.?\s*david/i

  # Comments may say anything: they explain WHY, and the why is often this
  # parish. It is executable lines that must not assert it.
  def code_lines(path)
    File.readlines(path).reject do |line|
      s = line.strip
      s.empty? || s.start_with?("#", "//", "*", "<%#", "<!--")
    end
  end

  def offending(path)
    code_lines(path).select { |l| l =~ PARISH }
  end

  # Everything a visitor is actually served.
  {
    "the web app manifest"   => "app/views/pwa/manifest.json.erb",
    "the page-not-found page" => "app/views/pages/not_found.html.erb",
    "the public layout"      => "app/views/layouts/application.html.erb",
    "the page template"      => "app/views/pages/show.html.erb",
    "what search engines are told" => "app/services/site/seo.rb",
    "the site drop"          => "app/drops/site_drop.rb",
    "the mailer"             => "app/mailers/user_mailer.rb"
  }.each do |what, path|
    it "#{what} names no particular parish" do
      bad = offending(Rails.root.join(path))

      expect(bad).to be_empty,
        -> { "#{path} asserts this parish:\n" + bad.map { |l| "    #{l.strip}" }.join("\n") }
    end
  end

  it "serves a page without any parish being named in Ruby" do
    build_page(slug: "home", title: "Home")
    Revision.live.site_settings.find_or_create_by!(key: "name").update!(value: "Holy Trinity")

    get "/"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Holy Trinity")
  end

  # A site nobody has configured should look unconfigured, not like us.
  it "falls back to nothing recognisable" do
    expect(SiteDrop::FALLBACK.values.join(" ")).not_to match(PARISH)
  end
end
