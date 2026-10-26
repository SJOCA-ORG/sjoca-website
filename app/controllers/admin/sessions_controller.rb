module Admin
  # Signing in and out. The only part of the admin a stranger can reach.
  class SessionsController < ApplicationController
    include Authentication

    skip_before_action :require_login, only: %i[new create]
    layout "admin"

    # Ten tries in three minutes, per address. Not per IP: a parish shares one,
    # and locking the building out because one person is guessing is its own
    # kind of failure.
    rate_limit to: 10, within: 3.minutes,
               by: -> { params.dig(:session, :email).to_s.downcase.presence || request.remote_ip },
               with: -> { redirect_to admin_login_path, alert: "Too many attempts. Wait a few minutes and try again." },
               only: :create

    def new
      redirect_to admin_root_path and return if signed_in?

      @email = params[:email]
    end

    def create
      user = User.authenticate(params.dig(:session, :email), params.dig(:session, :password))

      if user
        where = session[:after_sign_in]
        sign_in(user)
        redirect_to where.presence || admin_root_path
      else
        # Deliberately the same answer whether the address is unknown or the
        # password is wrong. Saying which would confirm who has an account.
        Rails.logger.warn(
          "admin sign-in failed for #{params.dig(:session, :email).to_s.truncate(60).inspect} from #{request.remote_ip}"
        )
        @email = params.dig(:session, :email)
        flash.now[:alert] = "That email and password did not match."
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      sign_out
      redirect_to admin_login_path, notice: "Signed out."
    end
  end
end
