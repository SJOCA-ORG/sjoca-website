module Admin
  # Getting a bulletin out of the system: a PDF for the printer, an HTML file
  # for the mailing list.
  #
  # Both come from the same page and the same blocks. They are not two
  # documents -- they are one document rendered for two different things, which
  # is why neither is built by hand.
  class BulletinsController < BaseController
    before_action :load_revision_and_page, except: :index

    # Every bulletin there is, from whichever revision it lives in.
    #
    # The exports began life as buttons in the editing pane, which answered
    # "how do I get the PDF" only while you happened to be editing that draft.
    # A bulletin is wanted again later -- reprinted, re-sent, checked against
    # what went out -- and after publishing the draft it was made in is gone.
    def index
      revisions = [Revision.live, *Revision.drafts].compact.uniq
      # .special, not .bulletins: every page with a layout of its own. A parish
      # that writes a "newsletter" template gets its newsletters listed here
      # without anybody changing this line.
      @printables = revisions.flat_map { |r|
        r.pages.special.map { |page| [page, r] }
      }.sort_by { |page, _| [page.dated_on || Date.new(1900), page.id] }.reverse

      @by_layout = @printables.group_by { |page, _| page.layout }
    end

    # Chrome prints it, over the same connection that drives the layout checks.
    # No wkhtmltopdf, no Prawn: the browser that renders the page is the one
    # that prints it, so what comes out is what was on screen.
    def pdf
      Tempfile.create([@page.dated_on.to_s.presence || "bulletin", ".pdf"], binmode: true) do |file|
        out, err, status = Open3.capture3(
          "node", Rails.root.join("script/bulletin_pdf.mjs").to_s, preview_url, file.path
        )
        result = (JSON.parse(out) rescue {})

        if !status.success? || result["error"]
          return redirect_back fallback_location: admin_revision_path(@revision),
                               alert: "The PDF could not be made: " \
                                      "#{result['error'].presence || err.to_s.lines.first}"
        end

        send_data File.binread(file.path), filename: filename("pdf"),
                  type: "application/pdf", disposition: "attachment"
      end
    end

    # A whole HTML file, not a fragment: it can be opened in a browser to check
    # it, and pasted into whatever sends the parish mail. Styles are inline --
    # see the bulletin_email template for why.
    def email
      body = Site::PageRenderer.new(@revision).chrome("bulletin_email", @page)
      send_data wrap(body), filename: filename("html"),
                type: "text/html", disposition: "attachment"
    end

    private

    def load_revision_and_page
      @revision = Revision.find(params[:revision_id])
      @page = @revision.pages.find_by(slug: params[:slug]) or
        raise ActiveRecord::RecordNotFound, "no page #{params[:slug].inspect}"
      Current.revision = @revision
    end

    def preview_url
      base = ENV.fetch("SITE_URL", "http://localhost:3000")
      "#{base}/#{@page.slug}?preview=#{@revision.preview_token}&bare=1"
    end

    def filename(extension)
      stem = @page.dated_on ? "bulletin-#{@page.dated_on.iso8601}" : @page.slug.tr("/", "-")
      "#{stem}.#{extension}"
    end

    # Mail clients want a complete document. The meta tags are the two that
    # actually matter: the character set, or accented names come out as
    # mojibake, and the viewport, because most of the parish reads on a phone.
    def wrap(body)
      <<~HTML
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{ERB::Util.html_escape(@page.title)}</title>
        </head>
        <body style="margin:0;padding:0;background:#f4f4f4">
        #{body}
        </body>
        </html>
      HTML
    end
  end
end
