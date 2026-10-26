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
      password: "a-completely-new-one", password_confirmation: "a-completely-new-one"
    } }

    expect(response).to redirect_to("/admin/account")
    expect(user.reload.authenticate("a-completely-new-one")).to be_truthy
  end

  # A session left open on a shared computer gives somebody the cookie. It must
  # not also give them the account.
  it "refuses without the current password" do
    patch "/admin/account", params: { user: {
      current_password: "not-it",
      password: "a-completely-new-one", password_confirmation: "a-completely-new-one"
    } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(user.reload.authenticate("a-completely-new-one")).to be_falsey
    expect(user.authenticate(SignInHelpers::PASSWORD)).to be_truthy
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
      password: "a-completely-new-one", password_confirmation: "a-different-one-here"
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
      password: "a-completely-new-one", password_confirmation: "a-completely-new-one"
    } }

    expect(User.find_by_token_for(:password_reset, token)).to be_nil
  end

  it "keeps you signed in afterwards" do
    patch "/admin/account", params: { user: {
      current_password: SignInHelpers::PASSWORD,
      password: "a-completely-new-one", password_confirmation: "a-completely-new-one"
    } }

    get "/admin"
    expect(response).to have_http_status(:ok)
  end
end
