require "net/http"
require "json"

module Anthropic
  # A thin wrapper over the Messages API. Net::HTTP rather than a gem, matching
  # how ChurchTrac::CalendarFeed already talks to the outside world.
  class Client
    class Error < StandardError; end

    ENDPOINT = URI("https://api.anthropic.com/v1/messages").freeze
    VERSION  = "2023-06-01".freeze
    TIMEOUT  = 120

    def initialize(api_key: self.class.api_key, model: self.class.model,
                   workspace_id: self.class.workspace_id)
      @api_key      = api_key
      @model        = model
      @workspace_id = workspace_id
    end

    def self.api_key
      ENV["ANTHROPIC_API_KEY"].presence ||
        Rails.application.credentials.dig(:anthropic, :api_key)
    end

    def self.model = ENV.fetch("ANTHROPIC_MODEL", "claude-opus-5")

    # An account-level key is not tied to a workspace, and the API then requires
    # the workspace to be named explicitly. A workspace-scoped key does not need
    # this -- and is the better option anyway, since a workspace can carry a
    # spend limit.
    def self.workspace_id
      ENV["ANTHROPIC_WORKSPACE_ID"].presence ||
        Rails.application.credentials.dig(:anthropic, :workspace_id)
    end

    def self.configured? = api_key.present?

    # An image, as a content block. The model can see photographs, which is how
    # a library of positionally-named files becomes searchable by what is in them.
    def self.image_block(bytes, content_type)
      { type: "image",
        source: { type: "base64", media_type: content_type, data: Base64.strict_encode64(bytes) } }
    end

    # 4096 was the default and it was the direct cause of two different bugs: a
    # stylesheet that could not be written back because 26KB is ~7,150 tokens,
    # and a turn that ended in silence because the reply was cut off mid-tool
    # call. The model is writing CSS and JavaScript here, which is exactly the
    # kind of output that runs long. This costs nothing unless it is used.
    MAX_TOKENS = 16_384

    # Nearly all of what this app sends is the SAME every call. One editing
    # session ran 30 turns for 5,979,000 input tokens and 87,000 output -- it
    # was paying, over and over, to re-read its own past: the instructions, the
    # 50-odd tool definitions, and a conversation that only ever grows. A turn
    # with ten tool calls re-sends the whole thing ten times.
    #
    # Cached input reads at a tenth the price. Three breakpoints, in the order
    # the API assembles a prompt:
    #
    #   tools      identical every call
    #   system     changes only when the stylesheet does
    #   messages   everything up to the newest exchange
    #
    # The last one is the real saving, because it grows: inside one turn, each
    # step caches the step before it.
    CACHE = { type: "ephemeral" }.freeze

    def call(system:, messages:, tools: [], max_tokens: MAX_TOKENS, cache: true)
      raise Error, "no Anthropic API key configured" if @api_key.blank?

      body = { model: @model, max_tokens: max_tokens,
               system: cache ? cacheable_system(system) : system,
               messages: cache ? cacheable_messages(messages) : messages }
      body[:tools] = cache ? cacheable_tools(tools) : tools if tools.any?

      response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true,
                                 open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        headers = { "x-api-key" => @api_key, "anthropic-version" => VERSION,
                    "content-type" => "application/json" }
        headers["anthropic-workspace-id"] = @workspace_id if @workspace_id.present?
        http.post(ENDPOINT.path, body.to_json, headers)
      end

      parsed = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Error, "Anthropic returned #{response.code} and #{response.body.bytesize} bytes of non-JSON"
      end

      raise Error, parsed.dig("error", "message") || "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parsed
    end

    private

    # cache_control can only sit on a content BLOCK, so a plain string system
    # prompt has to become one.
    def cacheable_system(system)
      return system unless system.is_a?(String)

      [{ type: "text", text: system, cache_control: CACHE }]
    end

    # Marking the LAST tool caches the whole list: the breakpoint covers
    # everything before it.
    def cacheable_tools(tools)
      return tools if tools.empty?

      tools[0..-2] + [tools.last.merge(cache_control: CACHE)]
    end

    # Cache everything except the newest exchange, so the growing history is
    # read from cache and only what is new is charged in full. A string content
    # has to become a block for the same reason as the system prompt.
    def cacheable_messages(messages)
      return messages if messages.size < 2

      marked = messages.dup
      i = marked.size - 2
      marked[i] = with_cache_breakpoint(marked[i])
      marked
    end

    def with_cache_breakpoint(message)
      content = message[:content] || message["content"]
      blocks = content.is_a?(String) ? [{ type: "text", text: content }] : content.dup
      return message unless blocks.is_a?(Array) && blocks.any?

      last = blocks.last
      return message unless last.is_a?(Hash)

      blocks[-1] = last.merge(cache_control: CACHE)
      message.merge(content: blocks).except("content")
    end
  end
end
