class PagesController < ApplicationController
  include RevisionScoped

  rescue_from Site::Renderer::Error, with: :template_error

  def show
    # /home and / served the same page at two addresses. A search engine reads
    # that as two pages with identical content and has to pick one; better to
    # pick for it. The canonical tag says / as well, but a redirect is the
    # unambiguous version and costs nothing.
    # On the REQUEST PATH, not on params[:path]: the root route supplies
    # "home" as a default, so testing the parameter redirected / to itself for
    # ever. The first version of this did exactly that.
    return redirect_to(root_path, status: :moved_permanently) if request.path == "/home" &&
                                                                 params[:preview].blank?

    @page = Page.in_revision(Current.revision).includes(sections: :blocks)
                .find_by(slug: params[:path])

    @theme_digest    = ThemeAsset.digest_for(Current.revision, "css")
    @theme_js_digest = ThemeAsset.js_for(Current.revision).present? &&
                       ThemeAsset.digest_for(Current.revision, "js")

    # A signed preview link must carry through to the stylesheet, or the browser
    # fetches it with no preview context and gets the LIVE styles -- a preview
    # showing the draft's content with the published site's appearance, which is
    # worse than no preview because it looks like it worked.
    @preview = params[:preview].presence

    renderer = Site::PageRenderer.new(Current.revision)
    @header  = renderer.chrome("header", @page)
    @footer  = renderer.chrome("footer", @page)

    @page_class = @page ? "page-#{@page.slug.tr('/', '-')}" : "page-not-found"

    # Always built -- a preview wants a sensible title in the tab like anything
    # else. What a preview does NOT get is the indexable half: canonical, Open
    # Graph, structured data. A draft is at a signed address and contains words
    # the parish has not agreed to publish.
    @seo = Site::Seo.new(@page, revision: Current.revision) if @page
    @indexable = @page.present? && !previewing?

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
