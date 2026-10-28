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
  # In spec/support/this_parish.rb, so the spec that reads rendered HTML uses
  # the same one. SJTB is in it because it was not, and that is how a monogram
  # in the DEFAULT header template survived -- seeded into every new
  # organization, so the first one anybody created would have carried this
  # parish at the top of every page.
  PARISH = ThisParish::PATTERN

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

  # Configuration is Ruby too, and it is the place where naming one customer
  # does not look like naming one customer -- it looks like a setting.
  #
  # config/environments/production.rb listed sjoca.org in config.hosts. True
  # while one organization ran per deployment, and quietly fatal afterwards: a
  # customer's domain added through the operator console would be refused by
  # Rails until somebody edited that file and redeployed, and the symptom is
  # "Blocked host", which reads like an outage rather than a setting.
  it "the production configuration names no particular organization" do
    bad = offending(Rails.root.join("config/environments/production.rb"))

    expect(bad).to be_empty, <<~MSG
      config/environments/production.rb names this parish:

        #{bad.map(&:strip).join("\n        ")}

      A hostname belongs in organization_hosts, where adding one needs no deploy.
      config.hosts asks Organization.known_host?.
    MSG
  end

  # What a NEW organization is built from.
  #
  # This spec used to read only the files serving the live site, and missed the
  # ones that create the next site. Those matter more: a mistake in the live
  # site's own templates is this parish's business, and a mistake in the
  # defaults is everybody's.
  describe "what a new organization starts from" do
    # Only the files a NEW organization is built from.
    #
    # Deliberately not all of db/seeds. content.yml and content.rb are THIS
    # parish's captured pages -- they name it on every line and should. The
    # distinction is whether a file is somebody's content or everybody's
    # starting point.
    def seed_and_starter_files
      # templates.rb AND the .liquid files it merges in -- DefaultTemplates.all
      # installs both into every new organization, and a glob that covered only
      # the Ruby file would have been checking two thirds of the defaults while
      # reading as though it checked them.
      [Rails.root.join("db/seeds/templates.rb").to_s] +
        Dir[Rails.root.join("db/seeds/templates/**/*.liquid")] +
        Dir[Rails.root.join("db/starters/**/*.{rb,yml,liquid,html}")]
    end

    it "has files to check" do
      expect(seed_and_starter_files).not_to be_empty
    end

    it "names no particular parish anywhere in them" do
      bad = seed_and_starter_files.flat_map do |path|
        offending(path).map { |l| "#{Pathname(path).relative_path_from(Rails.root)}: #{l.strip}" }
      end

      expect(bad).to be_empty, <<~MSG
        A new organization would be created carrying this parish:

          #{bad.join("\n          ")}

        These files are what every FUTURE site is built from. A fact about this
        parish belongs in its own settings, as a row -- see the brand setting in
        the header template for the shape of the fix.
      MSG
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
