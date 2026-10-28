module Operator
  # The console for whoever runs this app for other people.
  #
  # Two locks, and they are different in kind:
  #
  #   application_admin  -- WHO may be here. A customer's own superadmin is the
  #                         top of their organization and has no business here.
  #   the product host   -- WHERE it answers. An application admin signing in on
  #                         a customer's domain should be rare, so the console
  #                         is not reachable from one at all. Making it
  #                         impossible is better than logging it.
  #
  # Until an organization is marked `product` there is nowhere for the console to
  # live, so it answers anywhere -- otherwise designating the first one would
  # require a console that cannot be reached. The page says so loudly while that
  # is true.
  class BaseController < ApplicationController
    include Authentication

    before_action :require_application_admin
    before_action :require_the_product_host

    layout "admin"

    private

    def require_application_admin
      return if current_user&.application_admin?

      # 404, not 403. A customer's administrator poking at /operator learns
      # nothing about whether it exists.
      render plain: "Not found", status: :not_found
    end

    def require_the_product_host
      product = Organization.the_product
      return if product.nil?                                  # bootstrap: see above
      return if Current.organization == product

      render plain: "Not found", status: :not_found
    end

    def bootstrapping? = Organization.the_product.nil?
    helper_method :bootstrapping?

    def note!(action, organization:, detail: nil)
      OperatorAction.note!(action, organization: organization, user: current_user,
                           detail: detail, ip: request.remote_ip)
    end
  end
end
