require "rails_helper"

RSpec.describe "signing in", type: :request, signed_out: true do
  let!(:user) do
    User.create!(email: "itmanager@sjoca.org", password: SignInHelpers::PASSWORD,
                 role: "superadmin")
  end

  def attempt(email, password)
    post "/admin/login", params: { session: { email: email, password: password } }
  end

  it "lets the right password in" do
    attempt("itmanager@sjoca.org", SignInHelpers::PASSWORD)

    expect(response).to redirect_to("/admin")
    follow_redirect!
    expect(response).to have_http_status(:ok)
  end

  it "ignores the case of the address" do
    attempt("ItManager@SJOCA.org", SignInHelpers::PASSWORD)

    expect(response).to redirect_to("/admin")
  end

  it "turns the wrong password away" do
    attempt("itmanager@sjoca.org", "not-the-password")

    expect(response).to have_http_status(:unprocessable_content)
    get "/admin"
    expect(response).to redirect_to("/admin/login")
  end

  # Saying "no such account" would confirm which addresses exist, which is half
  # of what someone guessing needs.
  it "says the same thing whether the address exists or not" do
    attempt("itmanager@sjoca.org", "wrong")
    known = response.body[/did not match/]

    attempt("nobody@example.com", "wrong")
    unknown = response.body[/did not match/]

    expect(known).to be_present
    expect(unknown).to eq(known)
  end

  it "records when they last signed in" do
    expect { attempt("itmanager@sjoca.org", SignInHelpers::PASSWORD) }
      .to change { user.reload.last_signed_in_at }.from(nil)
  end

  # A session id handed out BEFORE signing in must not still be valid after, or
  # anyone who planted one in the browser is now signed in as well.
  it "issues a new session on sign-in" do
    get "/admin/login"
    before = response.headers["Set-Cookie"].to_s[/_sjoca[^;]*/]

    attempt("itmanager@sjoca.org", SignInHelpers::PASSWORD)
    after = response.headers["Set-Cookie"].to_s[/_sjoca[^;]*/]

    expect(after).to be_present
    expect(after).not_to eq(before)
  end

  it "sends you on to where you were going" do
    get "/admin/photos"
    expect(response).to redirect_to("/admin/login")

    attempt("itmanager@sjoca.org", SignInHelpers::PASSWORD)
    expect(response).to redirect_to("/admin/photos")
  end

  it "signs out" do
    attempt("itmanager@sjoca.org", SignInHelpers::PASSWORD)
    delete "/admin/logout"

    get "/admin"
    expect(response).to redirect_to("/admin/login")
  end

  # Attempts are counted in a cache that outlives a single example, so clear it
  # or the failed sign-ins above push this over the line before it starts.
  it "stops answering after too many attempts" do
    ActionController::Base.cache_store.clear

    11.times { attempt("itmanager@sjoca.org", "wrong") }

    expect(response).to redirect_to("/admin/login")
    follow_redirect!
    expect(response.body).to match(/Too many attempts/)
  end

  # The whole point of the model: a copy of the database is not a way in.
  it "never stores the password" do
    expect(user.reload.password_digest).not_to include(SignInHelpers::PASSWORD)
    expect(User.column_names).not_to include("password")
  end
end

# The spec that stops this being quietly undone. Someone adding an admin
# controller in six months does not have to remember anything: if it is not
# behind the login, this fails.
RSpec.describe "every admin page is behind the login", type: :request, signed_out: true do
  # The only pages a stranger may reach, and each is here on purpose. Adding to
  # this list should feel like a decision, because it is one.
  OPEN = [
    "/admin/login",          # how you get in
    "/admin/password/new",   # how you ask for a link when you cannot
    "/admin/password/edit"   # where that link lands
  ].freeze

  def self.admin_get_paths
    Rails.application.routes.routes.filter_map do |r|
      next unless r.verb.to_s.include?("GET")

      path = r.path.spec.to_s.sub(/\(\.:format\)\z/, "")
      next unless path.start_with?("/admin")
      next if OPEN.include?(path)

      # A plausible value for every placeholder: the filter must run before
      # anything tries to look the record up, so the id need not exist.
      path.gsub(/:[a-z_]+/) { |seg| seg == ":id" ? "1" : "1" }
    end.uniq
  end

  admin_get_paths.each do |path|
    it "refuses #{path} when signed out" do
      get path

      expect(response).to redirect_to("/admin/login"),
                          -> { "#{path} answered #{response.status} instead of sending you to sign in" }
    end
  end
end
