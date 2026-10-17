require "rails_helper"

# Two of Mitch's editing turns died with "no implicit conversion of Symbol into
# Integer" and no backtrace. The cause: look_at_it returned [] from its guard
# clauses -- copied from `verify`, which returns a list of problems -- while the
# caller expected a Hash or nil. An empty array is truthy in Ruby, so the guard
# passed and the next line asked an Array for [:screenshots].
#
# Every turn that changed something the guards declined to photograph crashed.
RSpec.describe Admin::Editor, "looking at its own work" do
  let(:revision) { Revision.tap { build_page }.open_sandbox }
  let(:editor) { described_class.new(revision, client: client) }
  let(:client) { instance_double(Anthropic::Client) }

  def look(performed) = editor.send(:look_at_it, performed)

  it "returns nil, not [], when nothing visual changed" do
    expect(look([{ "name" => "get_page", "read" => true }])).to be_nil
  end

  it "returns nil, not [], when nothing was touched" do
    expect(look([{ "name" => "add_styles" }])).to be_nil
  end

  it "returns nil when a visual change failed" do
    expect(look([{ "name" => "add_styles", "failed" => true }])).to be_nil
  end

  # The specific shape that crashed. [] is truthy; nil is not.
  it "never returns something truthy that cannot be asked for :screenshots" do
    [[{ "name" => "get_page", "read" => true }], [{ "name" => "add_styles" }], []].each do |performed|
      result = look(performed)
      next if result.nil?

      expect(result).to respond_to(:[])
      expect { result[:screenshots] }.not_to raise_error
    end
  end

  # A whole turn, with the model declining to call any tool. Before the fix this
  # raised TypeError instead of replying.
  it "completes a turn that changed styles without crashing" do
    allow(client).to receive(:call).and_return(
      { "content" => [{ "type" => "text", "text" => "Done." }], "usage" => {} }
    )
    tools = editor.instance_variable_get(:@tools)
    tools.call("add_styles", { "css" => ".x { color: red }" })

    result = editor.call("make the heading red")

    expect(result.error).to be_nil
    expect(result.reply).to include("Done")
  end
end
