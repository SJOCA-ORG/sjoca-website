# Signing in, for the specs that work behind the login.
#
# Request specs post the real form rather than poking the session directly, so
# the login itself is exercised by every one of them. If sign-in breaks, the
# whole suite says so instead of quietly carrying on with a forged session.
module SignInHelpers
  PASSWORD = "a-password-long-enough".freeze

  def superadmin
    @superadmin ||= User.create!(email: "itmanager@sjoca.org", password: PASSWORD,
                                 name: "Test Admin", role: "superadmin")
  end

  def sign_in(user = superadmin)
    post "/admin/login", params: { session: { email: user.email, password: PASSWORD } }
    raise "sign-in failed in a spec: #{response.status}" unless response.redirect?

    user
  end
end

RSpec.configure do |config|
  config.include SignInHelpers, type: :request

  # Nearly every admin spec needs to be signed in; the ones testing the login
  # itself opt out with `signed_out: true`.
  config.before(:each, type: :request) do |example|
    # The limiter counts every attempt, successful ones included, and the cache
    # outlives an example. Without this the eleventh spec in the suite starts
    # being turned away -- which is the limiter working exactly as asked, in
    # the one place we do not want it.
    ActionController::Base.cache_store.clear

    sign_in unless example.metadata[:signed_out]
  end
end
