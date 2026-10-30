module Operator
  # Everything that has to happen for a new organization to be a working website
  # with somebody able to sign in to it.
  #
  # One object rather than a controller action, because this is the sequence
  # spec/requests/a_new_organization_spec.rb was written to describe before any
  # of it existed: a hostname, a first published revision, templates, a home
  # page, an owner, an invitation. The spec called each step by hand; now it
  # calls this, and the assertions did not have to change.
  #
  # All of it in one transaction. A half-created organization -- a hostname with
  # no revision, an owner with nothing to administer -- is worse than none,
  # because the next attempt collides with the leftovers.
  class CreateOrganization
    Result = Struct.new(:organization, :owner, :errors, keyword_init: true) do
      def ok? = errors.empty?
    end

    # A password nobody will ever use or see. The owner sets their own through
    # the invitation; this exists because has_secure_password insists on one,
    # and leaving it blank would mean an account with no digest at all.
    # The suffix guarantees the mix User requires, which random base58 does not.
    def self.unguessable_password = "#{SecureRandom.base58(24)}Aa1!"

    def initialize(name:, slug:, host:, owner_email:, canonical_url: nil,
                   starter: "blank", by: nil, ip: nil)
      @name = name.to_s.strip
      @slug = slug.to_s.strip.downcase
      @host = host.to_s.strip.downcase
      @owner_email = owner_email.to_s.strip.downcase
      @canonical_url = canonical_url.presence || "https://#{@host}"
      @starter = starter.presence
      @by = by
      @ip = ip
    end

    def call
      organization = nil
      owner = nil

      ActiveRecord::Base.transaction do
        organization = Organization.create!(
          name: @name, slug: @slug, canonical_url: @canonical_url
        )
        organization.add_host(@host)

        # A starter is an ORGANIZATION, and this is a copy of its website --
        # pages, templates, stylesheet, photographs and all. Which means a look
        # is made by using the product rather than by writing YAML, and that a
        # customer gets exactly what somebody looked at and approved.
        starter = Starters.chosen(@starter)
        Organization.acting_as(starter) { Revision.live }
                    .copy_into(organization, title: "First")

        # acting_as for the rest: the moment this organization exists there are
        # two of them, so nothing is implicit any more and every create below
        # would otherwise land nowhere.
        Organization.acting_as(organization) do
          # The one setting a brand new site cannot do without: something to
          # call itself. After the copy, so it wins over the starter's own name.
          Revision.live.site_settings
                  .find_or_initialize_by(key: "name").update!(value: @name)

          owner = User.create!(email: @owner_email, role: "superadmin",
                               password: self.class.unguessable_password)
        end

        OperatorAction.note!(:created, organization: organization, user: @by,
                             detail: "#{@slug} at #{@host}, from #{starter.name}", ip: @ip)
        OperatorAction.note!(:invited, organization: organization, user: @by,
                             detail: @owner_email, ip: @ip)

        UserMailer.invite(owner, owner.generate_token_for(:invite),
                          organization: organization).deliver_later
      end

      Result.new(organization: organization, owner: owner, errors: [])
    rescue ActiveRecord::RecordInvalid => e
      Result.new(organization: nil, owner: nil, errors: e.record.errors.full_messages)
    rescue ActiveRecord::RecordNotUnique => e
      # A validation that was not there, or a race between two attempts. Either
      # way the transaction is gone and the operator needs a sentence, not a
      # stack trace. Kept even though User now validates its email: the database
      # is the backstop precisely for what the model has not thought of.
      Rails.logger.warn("organization creation hit a unique index: #{e.message.truncate(200)}")
      Result.new(organization: nil, owner: nil,
                 errors: ["that hostname or email is already taken"])
    end
  end
end
