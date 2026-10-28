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

    # The same sentence wherever a token is refused. Which reason it was -- bad,
    # expired, used, or for a different organization -- is nobody's business but
    # the person who has the right link.
    EXPIRED = "That link has expired or has already been used. Ask for another.".freeze

    def create
      email = params.dig(:password, :email).to_s.strip.downcase
      user = User.find_by(email: email)

      if user
        # The organization goes WITH the job. It is rendered in a worker, where
        # there is no request and Current.organization is nothing.
        UserMailer.password_reset(user, user.generate_token_for(:password_reset),
                                  organization: Current.organization).deliver_later
      else
        Rails.logger.info("password reset asked for an address with no account: #{email.truncate(60).inspect}")
      end

      # The SAME answer either way. Saying "no such account" would turn this
      # form into a way of finding out who has one.
      redirect_to admin_login_path,
                  notice: "If that address has an account, a link is on its way. It lasts two hours."
    end

    def edit
      @user = user_from_token
      return if @user

      redirect_to admin_new_password_path, alert: EXPIRED
    end

    def update
      @user = user_from_token
      return redirect_to(admin_new_password_path, alert: EXPIRED) if @user.nil?

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

    private

    # A valid token, for the right person, on the WRONG organization's hostname.
    #
    # The token is signed, unexpired and theirs, so this is not a way in to
    # anybody else's account -- which is why it went unnoticed. What it was was
    # a dead end: the reset succeeded, consumed the token, signed them in, and
    # the very next request bounced them to a sign-in page that would not have
    # them, because may_act_in? is checked on every request. They were left with
    # a changed password, a spent link and no explanation.
    #
    # Refusing before the token is spent means they can follow the right link
    # when they find it.
    def user_from_token
      user = User.find_by_token_for(:password_reset, params[:token])
      return nil if user.nil?
      return nil unless user.may_act_in?(Current.organization)

      user
    end
  end
end
