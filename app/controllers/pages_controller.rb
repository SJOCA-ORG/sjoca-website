class PagesController < ApplicationController
  include RevisionScoped

  rescue_from Site::Renderer::Error, with: :template_error

  def show
    @page = Page.in_revision(Current.revision).includes(sections: :blocks)
                .find_by(slug: params[:path])

    @theme_digest    = ThemeAsset.digest_for(Current.revision, "css")
    @theme_js_digest = ThemeAsset.js_for(Current.revision).present? &&
                       ThemeAsset.digest_for(Current.revision, "js")

    renderer = Site::PageRenderer.new(Current.revision)
    @header  = renderer.chrome("header", @page)
    @footer  = renderer.chrome("footer", @page)

    if @page
      @body = renderer.body(@page)
      render :show
    else
      render :not_found, status: :not_found
    end
  end

  private

  # A broken template must not take the whole site down with a stack trace. In
  # development it shows what is wrong; in production it is a 500 page.
  def template_error(error)
    Rails.logger.error("Liquid template error: #{error.message}")
    raise error if Rails.env.local?

    render plain: "This page is temporarily unavailable.", status: :internal_server_error
  end
end
