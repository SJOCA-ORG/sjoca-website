require "rails_helper"

# A form inside a form is invalid HTML, and the browser does not complain: the
# parser closes the outer form at the inner one, so everything after it --
# including the textarea and the Send button -- stops belonging to any form.
# Nothing submits, no request reaches the server, and there is nothing in any
# log to find.
#
# It happened: button_to builds a <form>, and putting "just save them to the
# library" inside the message form broke sending entirely.
RSpec.describe "admin markup", type: :request do
  def nested_forms?(html)
    depth = 0
    html.scan(%r{<form\b|</form>}).each do |tag|
      depth += tag == "</form>" ? -1 : 1
      return true if depth > 1
    end
    false
  end

  let(:revision) { Revision.tap { build_page }.open_sandbox }

  it "never nests a form inside a form on the editing page" do
    get "/admin/revisions/#{revision.id}"

    expect(nested_forms?(response.body)).to be(false)
  end

  it "never nests a form on the editing page while a turn is running" do
    revision.messages.create!(role: "user", content: "a change")
    revision.messages.create!(role: "assistant", state: "working", content: "", progress: [])

    get "/admin/revisions/#{revision.id}"

    expect(nested_forms?(response.body)).to be(false)
  end

  it "never nests a form in the photo library" do
    get "/admin/photos"

    expect(nested_forms?(response.body)).to be(false)
  end

  it "never nests a form on the revisions list" do
    get "/admin"

    expect(nested_forms?(response.body)).to be(false)
  end

  # The thing that actually matters: you can still send.
  it "keeps the message box and its Send button inside the message form" do
    get "/admin/revisions/#{revision.id}"

    form = response.body[%r{<form[^>]*id="say".*?</form>}m]
    expect(form).to include("textarea")
    expect(form).to include('type="submit"')
  end
end
