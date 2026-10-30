module Operator
  # The list of accounts, and the handful of things one does to an account.
  #
  # It lists accounts; it does not show their content. Names, hostnames, how
  # many pages and photographs, when somebody last signed in. To work inside one
  # you go to it, which is a separate act and leaves a row in operator_actions.
  # That distinction is what makes "we can see everything" an auditable fact
  # rather than just a true one.
  class OrganizationsController < BaseController
    def index
      # Tenants. The sample sites are organizations too, and they belong in a
      # chooser rather than in a list of accounts.
      @organizations = Organization.tenants.order(:name).to_a
      @counts = @organizations.index_with { |org| counts_for(org) }
      @recent = OperatorAction.newest_first.limit(20).includes(:user, :organization)
    end

    def new
      @form = { slug: "", name: "", host: "", owner_email: "", starter: Starters::DEFAULT }
      @starters = Starters.all
    end

    def create
      result = CreateOrganization.new(
        name: params[:name], slug: params[:slug], host: params[:host],
        canonical_url: params[:canonical_url], owner_email: params[:owner_email],
        starter: params[:starter], by: current_user, ip: request.remote_ip
      ).call

      if result.ok?
        redirect_to operator_root_path,
                    notice: "#{result.organization.name} created. #{result.owner.email} has been invited."
      else
        @form = params.permit(:name, :slug, :host, :canonical_url, :owner_email, :starter).to_h
        @starters = Starters.all
        flash.now[:alert] = result.errors.to_sentence
        render :new, status: :unprocessable_content
      end
    end

    # Going to an organization's own admin, on its own hostname.
    #
    # Deliberately a redirect rather than a session flag that makes this app
    # pretend to be somewhere else. The hostname decides which organization a
    # request is for, everywhere else in the app, and carving an exception for
    # the one person with universal access is how that invariant stops being
    # one. The cost is signing in again on that host, which at this boundary is
    # a feature.
    #
    # In development every organization shares localhost, so this lands back
    # here. That is a development inconvenience and not worth a code path.
    def enter
      organization = Organization.find(params[:id])
      note!(:entered, organization: organization)

      redirect_to "#{organization.canonical_url}/admin", allow_other_host: true
    end

    def suspend
      organization = Organization.find(params[:id])
      organization.update!(active: false)
      note!(:suspended, organization: organization)

      redirect_to operator_root_path, notice: "#{organization.name} suspended. Nothing was deleted."
    end

    def resume
      organization = Organization.find(params[:id])
      organization.update!(active: true)
      note!(:resumed, organization: organization)

      redirect_to operator_root_path, notice: "#{organization.name} is live again."
    end

    private

    # Counted inside each organization, because every one of these models is
    # scoped and would otherwise count nothing.
    def counts_for(organization)
      Organization.acting_as(organization) do
        live = Revision.live
        {
          pages: live ? Page.in_revision(live).count : 0,
          photos: Photo.count,
          revisions: Revision.count,
          editors: User.where(organization_id: organization.id).count,
          last_in: User.where(organization_id: organization.id).maximum(:last_signed_in_at)
        }
      end
    end
  end
end
