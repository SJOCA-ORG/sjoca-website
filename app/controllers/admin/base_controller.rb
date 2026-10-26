module Admin
  # Everything behind the login.
  #
  # Two locks, deliberately. The login is the real one. ADMIN_ENABLED is a
  # switch, so the app can be deployed -- and the database copied up -- while
  # the admin stays completely dark, and so there is a way to turn it off in a
  # hurry that does not involve changing anyone's password.
  class BaseController < ApplicationController
    include RevisionScoped
    include Authentication

    before_action :refuse_when_switched_off

    layout "admin"

    private

    def refuse_when_switched_off
      return if Rails.env.local? || ENV["ADMIN_ENABLED"] == "true"

      render plain: "The editor is not switched on for this site.", status: :forbidden
    end
  end
end
