class PagesController < ApplicationController
  include RevisionScoped

  # The navigation is part of the layout, so it has to be there for the
  # not-found page too, not just when a page resolves.
  before_action :load_nav

  def show
    @page = Page.in_revision(Current.revision).includes(sections: :blocks)
                .find_by(slug: params[:path])
    render "not_found", status: :not_found unless @page
  end

  private

  def load_nav
    @nav = Page.in_revision(Current.revision).top_level.in_nav
  end
end
