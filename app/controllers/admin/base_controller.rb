module Admin
  # Everything behind the login.
  #
  # There used to be a second lock here -- ADMIN_ENABLED, an environment
  # variable production had to be given before the editor would answer at all.
  # It was built when there was no login, when it was the ONLY protection, and
  # it was kept for a while out of caution.
  #
  # Removed on 26 October 2026. With a real login it bought almost nothing, and
  # it brought its own bug: the sign-in and password-reset pages are separate
  # controllers and never inherited it, so "switched off" quietly did not mean
  # switched off. A second mechanism that is nearly right is worse than one
  # mechanism that is right.
  class BaseController < ApplicationController
    include RevisionScoped
    include Authentication

    layout "admin"
  end
end
