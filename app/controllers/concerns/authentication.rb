# Who is signed in, and refusing to go on when nobody is.
module Authentication
  extend ActiveSupport::Concern

  # Twelve hours. Long enough that a morning of editing is not interrupted;
  # short enough that a session left open on a parish hall computer expires
  # before anyone wanders past it the next day.
  IDLE_LIMIT = 12.hours

  included do
    before_action :require_login
    helper_method :current_user, :signed_in?
  end

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = begin
      id = session[:user_id]
      stamp = session[:signed_in_at]
      if id.blank? || stamp.blank? || Time.zone.at(stamp) < IDLE_LIMIT.ago
        sign_out if id.present?    # expired: clear it rather than re-checking forever
        nil
      else
        User.find_by(id: id)
      end
    end
  end

  def signed_in? = current_user.present?

  def require_login
    return if signed_in?

    # Remember where they were going, so signing in finishes the job rather
    # than dumping them on a front page to navigate again.
    session[:after_sign_in] = request.fullpath if request.get?
    redirect_to admin_login_path
  end

  # reset_session FIRST: a session id handed out before signing in must not
  # still be valid afterwards, or anyone who planted one is now signed in too.
  def sign_in(user)
    reset_session
    session[:user_id] = user.id
    session[:signed_in_at] = Time.current.to_i
    user.update_columns(last_signed_in_at: Time.current)
  end

  def sign_out
    reset_session
    @current_user = nil
  end
end
