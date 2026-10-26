require "rails_helper"

RSpec.describe "your account", type: :request do
  let(:user) { superadmin }

  it "shows who you are" do
    get "/admin/account"

    expect(response.body).to include(user.email)
  end

  it "changes the password" do
    patch "/admin/account", params: { user: {
      current_password: SignInHelpers::PASSWORD,
      password: "Completely-New-27", password_confirmation: "Completely-New-27"
    } }

    expect(response).to redirect_to("/admin/account")
    expect(user.reload.authenticate("Completely-New-27")).to be_truthy
  end

  # A session left open on a shared computer gives somebody the cookie. It must
  # not also give them the account.
  it "refuses without the current password" do
    patch "/admin/account", params: { user: {
      current_password: "not-it",
      password: "Completely-New-27", password_confirmation: "Completely-New-27"
    } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.authenticate("Completely-New-27")).to be_falsey
    expect(user.authenticate(SignInHelpers::PASSWORD)).to be_truthy
  end

  describe "what counts as a password" do
    def try(pw)
      patch "/admin/account", params: { user: {
        current_password: SignInHelpers::PASSWORD, password: pw, password_confirmation: pw
      } }
      response.status
    end

    # Eight, with a capital, a small letter, and a number or symbol.
    it "accepts eight characters with a mix" do
      expect(try("Parish24")).to eq(302)
    end

    it "accepts a symbol in place of a number" do
      expect(try("Parish-x")).to eq(302)
    end

    { "Short1A"       => "seven characters",
      "parish24x"     => "no capital",
      "PARISH24X"     => "no small letter",
      "ParishChurch"  => "no number or symbol" }.each do |pw, why|
      it "refuses #{pw.inspect} — #{why}" do
        expect(try(pw)).to eq(422)
        expect(user.reload.authenticate(pw)).to be_falsey
      end
    end
  end

  it "refuses a new password that is too short" do
    patch "/admin/account", params: { user: {
      current_password: SignInHelpers::PASSWORD,
      password: "short", password_confirmation: "short"
    } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.authenticate(SignInHelpers::PASSWORD)).to be_truthy
  end

  it "refuses two that do not match" do
    patch "/admin/account", params: { user: {
      current_password: SignInHelpers::PASSWORD,
      password: "Completely-New-27", password_confirmation: "Different-Here-28"
    } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.authenticate(SignInHelpers::PASSWORD)).to be_truthy
  end

  # Changing the password cancels every reset link already issued -- including
  # one a thief might be holding.
  it "cancels outstanding reset links" do
    token = user.generate_token_for(:password_reset)

    patch "/admin/account", params: { user: {
      current_password: SignInHelpers::PASSWORD,
      password: "Completely-New-27", password_confirmation: "Completely-New-27"
    } }

    expect(User.find_by_token_for(:password_reset, token)).to be_nil
  end

  it "keeps you signed in afterwards" do
    patch "/admin/account", params: { user: {
      current_password: SignInHelpers::PASSWORD,
      password: "Completely-New-27", password_confirmation: "Completely-New-27"
    } }

    get "/admin"
    expect(response).to have_http_status(:ok)
  end
end
