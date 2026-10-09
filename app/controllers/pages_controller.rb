class PagesController < ApplicationController
  # The navigation is part of the layout, so it has to be there for the
  # not-found page too, not just when a page resolves.
  before_action :load_nav

  def show
    @page = Page.includes(sections: :blocks).find_by(slug: params[:path])
    render "not_found", status: :not_found unless @page
  end

  private

  def load_nav
    @nav = Page.top_level.in_nav
  end
end
