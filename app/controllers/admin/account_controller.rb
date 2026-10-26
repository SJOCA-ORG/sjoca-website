module Admin
  # Your own account. One page, one thing to do on it.
  class AccountController < BaseController
    def show; end

    def update
      # The CURRENT password, first. A session left open on a parish hall
      # computer should not be enough to take the account over -- whoever walks
      # past has the cookie but not the password.
      unless current_user.authenticate(params.dig(:user, :current_password))
        flash.now[:alert] = "That is not your current password."
        return render :show, status: :unprocessable_content
      end

      if current_user.update(password: params.dig(:user, :password),
                             password_confirmation: params.dig(:user, :password_confirmation))
        # A new session, so the cookie that was valid a moment ago is not. It
        # also quietly cancels every password-reset link already issued.
        sign_in(current_user)
        redirect_to admin_account_path, notice: "Password changed."
      else
        flash.now[:alert] = current_user.errors.full_messages.to_sentence
        current_user.reload   # do not leave a half-changed object on the page
        render :show, status: :unprocessable_content
      end
    end
  end
end
