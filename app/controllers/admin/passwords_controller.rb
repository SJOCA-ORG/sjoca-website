module Admin
  # Forgetting a password, and setting a new one.
  #
  # Open to strangers by necessity -- somebody locked out cannot sign in first --
  # so every answer here is deliberately uninformative.
  class PasswordsController < ApplicationController
    include Authentication

    skip_before_action :require_login
    layout "admin"

    # Three a quarter of an hour, by address. Enough for a person who mistypes
    # their own email; not enough to use this as a way to post mail to someone
    # repeatedly.
    rate_limit to: 3, within: 15.minutes,
               by: -> { params.dig(:password, :email).to_s.downcase.presence || request.remote_ip },
               with: -> { redirect_to admin_new_password_path, alert: "Too many requests. Try again shortly." },
               only: :create

    def new; end

    def create
      email = params.dig(:password, :email).to_s.strip.downcase
      user = User.find_by(email: email)

      if user
        UserMailer.password_reset(user, user.generate_token_for(:password_reset)).deliver_later
      else
        Rails.logger.info("password reset asked for an address with no account: #{email.truncate(60).inspect}")
      end

      # The SAME answer either way. Saying "no such account" would turn this
      # form into a way of finding out who has one.
      redirect_to admin_login_path,
                  notice: "If that address has an account, a link is on its way. It lasts two hours."
    end

    def edit
      @user = User.find_by_token_for(:password_reset, params[:token])
      return if @user

      redirect_to admin_new_password_path,
                  alert: "That link has expired or has already been used. Ask for another."
    end

    def update
      @user = User.find_by_token_for(:password_reset, params[:token])
      return redirect_to(admin_new_password_path, alert: "That link has expired or has already been used. Ask for another.") if @user.nil?

      if @user.update(password: params.dig(:password, :password),
                      password_confirmation: params.dig(:password, :password_confirmation))
        # Changing the password invalidates every outstanding link, this one
        # included. Signing them in here saves a pointless second step.
        sign_in(@user)
        redirect_to admin_root_path, notice: "Password changed."
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end
  end
end
