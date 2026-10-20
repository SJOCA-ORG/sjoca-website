require "rails_helper"

# Mitch had to reword a long paragraph by copying it into a document, editing
# it there, and pasting it back -- while the text was on screen the whole time.
# This is the short way round, and it deliberately does not go through the AI:
# somebody who knows the words they want should not have to describe them to
# anybody first.
RSpec.describe "editing a block by clicking it", type: :request do
  let(:revision) { Revision.tap { build_page(slug: "home", title: "Home") }.open_sandbox }
  let(:page) { revision.pages.find_by(slug: "home") }
  let(:section) { page.sections.create!(revision: revision, position: 0, style: "plain") }

  def block(kind: "text", content: "The parish council meets on the first Tuesday.")
    section.blocks.create!(revision: revision, kind: kind, content: content, position: 0)
  end

  describe "asking what a block is" do
    it "gives back the raw content, not the rendered version" do
      b = block(content: "A sentence with <em>markup</em> in it.")

      get "/admin/revisions/#{revision.id}/blocks/#{b.id}"

      expect(response.parsed_body["content"]).to eq("A sentence with <em>markup</em> in it.")
    end

    it "says which page it is on, so the editor can say so" do
      b = block

      get "/admin/revisions/#{revision.id}/blocks/#{b.id}"

      expect(response.parsed_body["page"]).to eq("home")
    end

    it "marks words as editable" do
      get "/admin/revisions/#{revision.id}/blocks/#{block(kind: 'heading').id}"

      expect(response.parsed_body["editable"]).to be(true)
    end

    # A textarea over an image's content would be a trap: there is nothing in
    # it a person would want to type.
    it "marks a photograph as not editable, and names it" do
      b = section.blocks.create!(revision: revision, kind: "image",
                                 asset_name: "home-hero", asset_version: 1, position: 1)

      get "/admin/revisions/#{revision.id}/blocks/#{b.id}"

      expect(response.parsed_body["editable"]).to be(false)
      expect(response.parsed_body["photo"]).to eq("home-hero")
    end
  end

  describe "saving an edit" do
    it "changes the words" do
      b = block

      patch "/admin/revisions/#{revision.id}/blocks/#{b.id}",
            params: { content: "The parish council meets on the second Tuesday." }

      expect(b.reload.content).to eq("The parish council meets on the second Tuesday.")
    end

    it "allows an empty paragraph to be emptied" do
      b = block

      patch "/admin/revisions/#{revision.id}/blocks/#{b.id}", params: { content: "" }

      expect(b.reload.content).to eq("")
    end

    it "refuses to put a textarea's contents into a photograph" do
      b = section.blocks.create!(revision: revision, kind: "image",
                                 asset_name: "home-hero", asset_version: 1, position: 1)

      patch "/admin/revisions/#{revision.id}/blocks/#{b.id}", params: { content: "words" }

      expect(response).to have_http_status(:unprocessable_content)
      expect(b.reload.content).to be_blank
    end
  end

  # Mitch's correction: clicking one block at a time was the wrong shape,
  # because a thought somebody wants to reword is rarely one paragraph.
  describe "rewriting several blocks as one piece of prose" do
    it "hands a multi-block rewrite to the conversation, not straight to the database" do
      first = block(content: "One.")
      second = section.blocks.create!(revision: revision, kind: "text",
                                      content: "Two.", position: 1)

      expect {
        post "/admin/revisions/#{revision.id}/blocks/rewrite",
             params: { block_ids: [first.id, second.id], content: "One and two, rewritten." }
      }.to change { revision.messages.count }.by(2)

      expect(response.parsed_body["handled"]).to eq("conversation")
    end

    # Deciding where paragraphs fall is judgement. Writing the text straight
    # into the blocks it came from would assume the shape never changes.
    it "leaves the blocks alone until the conversation has looked at them" do
      first = block(content: "One.")
      second = section.blocks.create!(revision: revision, kind: "text",
                                      content: "Two.", position: 1)

      post "/admin/revisions/#{revision.id}/blocks/rewrite",
           params: { block_ids: [first.id, second.id], content: "Rewritten." }

      expect(first.reload.content).to eq("One.")
      expect(second.reload.content).to eq("Two.")
    end

    it "tells the conversation what was there and what it should say" do
      first = block(content: "The old words.")

      post "/admin/revisions/#{revision.id}/blocks/rewrite",
           params: { block_ids: [first.id, block(content: "More old words.").id],
                     content: "The new words." }

      asked = revision.messages.where(role: "user").last.content
      expect(asked).to include("The old words.")
      expect(asked).to include("The new words.")
      expect(asked).to include("/home")
    end

    # One paragraph in, one paragraph out: no judgement needed, so no turn.
    it "saves a single block directly, without troubling the conversation" do
      only = block(content: "Just this one.")

      expect {
        post "/admin/revisions/#{revision.id}/blocks/rewrite",
             params: { block_ids: [only.id], content: "Reworded." }
      }.not_to change { revision.messages.count }

      expect(only.reload.content).to eq("Reworded.")
      expect(response.parsed_body["handled"]).to eq("directly")
    end

    it "refuses an empty selection" do
      post "/admin/revisions/#{revision.id}/blocks/rewrite",
           params: { block_ids: [], content: "words" }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # The overlay belongs to the admin's preview pane. The public site must
  # render none of it.
  describe "where the overlay appears" do
    # `revision` is lazy, so without this the live site does not exist at all
    # in the example below and the failure says nothing about the overlay.
    before { block }

    it "is in the preview pane" do
      get "/?preview=#{revision.preview_token}&bare=1"

      expect(response.body).to include("edit-menu")
    end

    it "is NOT on the live site" do
      get "/"

      expect(response.body).not_to include("edit-menu")
    end

    it "is not in an ordinary preview opened in a real tab" do
      get "/?preview=#{revision.preview_token}"

      expect(response.body).not_to include("edit-menu")
    end
  end

  # Without these a click cannot say which block it landed on.
  it "renders blocks carrying their id" do
    block

    get "/?preview=#{revision.preview_token}&bare=1"

    expect(response.body).to match(/data-block="\d+"/)
  end
end
