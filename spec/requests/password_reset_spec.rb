require "rails_helper"

RSpec.describe "resetting a password", type: :request, signed_out: true do
  let!(:user) do
    User.create!(email: "itmanager@sjoca.org", password: SignInHelpers::PASSWORD,
                 role: "superadmin")
  end

  def ask_for(email)
    ActionController::Base.cache_store.clear   # the limiter counts across examples
    post "/admin/password", params: { password: { email: email } }
  end

  def token = user.generate_token_for(:password_reset)

  describe "asking" do
    it "sends a link" do
      expect { perform_enqueued_jobs { ask_for("itmanager@sjoca.org") } }
        .to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(["itmanager@sjoca.org"])
      expect(mail.body.encoded).to include("/admin/password/edit?token=")
    end

    it "sends nothing for an address with no account" do
      expect { perform_enqueued_jobs { ask_for("nobody@example.com") } }
        .not_to change { ActionMailer::Base.deliveries.size }
    end

    # Otherwise the form becomes a way of discovering who has an account.
    it "answers identically either way" do
      ask_for("itmanager@sjoca.org")
      known = [response.status, flash[:notice]]

      ask_for("nobody@example.com")
      expect([response.status, flash[:notice]]).to eq(known)
    end

    it "stops after three requests" do
      ActionController::Base.cache_store.clear
      4.times { post "/admin/password", params: { password: { email: "itmanager@sjoca.org" } } }

      follow_redirect!
      expect(response.body).to match(/Too many requests/)
    end
  end

  describe "using the link" do
    it "sets the new password and signs them in" do
      patch "/admin/password", params: { token: token, password: {
        password: "a-brand-new-password", password_confirmation: "a-brand-new-password"
      } }

      expect(response).to redirect_to("/admin")
      expect(user.reload.authenticate("a-brand-new-password")).to be_truthy
      get "/admin"
      expect(response).to have_http_status(:ok)      # already signed in
    end

    # The important one. A link used once must not work twice -- and because
    # the token carries the password digest, changing the password kills it.
    it "cannot be used a second time" do
      t = token
      patch "/admin/password", params: { token: t, password: {
        password: "a-brand-new-password", password_confirmation: "a-brand-new-password"
      } }

      patch "/admin/password", params: { token: t, password: {
        password: "something-else-again", password_confirmation: "something-else-again"
      } }

      expect(response).to redirect_to("/admin/password/new")
      expect(user.reload.authenticate("something-else-again")).to be_falsey
      expect(user.authenticate("a-brand-new-password")).to be_truthy
    end

    it "expires after two hours" do
      t = token
      travel 2.hours + 1.minute do
        get "/admin/password/edit", params: { token: t }
        expect(response).to redirect_to("/admin/password/new")
      end
    end

    it "is still good an hour later" do
      t = token
      travel 1.hour do
        get "/admin/password/edit", params: { token: t }
        expect(response).to have_http_status(:ok)
      end
    end

    it "refuses a made-up token" do
      get "/admin/password/edit", params: { token: "not-a-real-token" }
      expect(response).to redirect_to("/admin/password/new")
    end

    it "will not accept a password that is too short" do
      patch "/admin/password", params: { token: token, password: {
        password: "short", password_confirmation: "short"
      } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate("short")).to be_falsey
    end

    it "will not accept two that do not match" do
      patch "/admin/password", params: { token: token, password: {
        password: "a-brand-new-password", password_confirmation: "a-different-one-entirely"
      } }

      expect(response).to have_http_status(:unprocessable_content)
      expect(user.reload.authenticate("a-brand-new-password")).to be_falsey
    end
  end
end
