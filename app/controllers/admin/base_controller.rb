module Admin
  # There is no authentication yet, deliberately: this runs locally while the
  # editing loop is built. What there IS, is a refusal to serve in production,
  # so an accidental deploy cannot expose an unauthenticated admin with write
  # access to the parish site.
  #
  # When login arrives it replaces this guard; nothing else here changes.
  class BaseController < ApplicationController
    include RevisionScoped

    before_action :refuse_in_production

    layout "admin"

    private

    def refuse_in_production
      return if Rails.env.local? || ENV["ADMIN_ENABLED"] == "true"

      render plain: "The admin is not available on this deployment.", status: :forbidden
    end
  end
end
