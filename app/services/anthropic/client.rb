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

    def initialize(api_key: self.class.api_key, model: self.class.model)
      @api_key = api_key
      @model   = model
    end

    def self.api_key
      ENV["ANTHROPIC_API_KEY"].presence ||
        Rails.application.credentials.dig(:anthropic, :api_key)
    end

    def self.model = ENV.fetch("ANTHROPIC_MODEL", "claude-sonnet-5")

    def self.configured? = api_key.present?

    def call(system:, messages:, tools: [], max_tokens: 4096)
      raise Error, "no Anthropic API key configured" if @api_key.blank?

      body = { model: @model, max_tokens: max_tokens, system: system, messages: messages }
      body[:tools] = tools if tools.any?

      response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true,
                                 open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.post(ENDPOINT.path, body.to_json,
                  "x-api-key" => @api_key, "anthropic-version" => VERSION,
                  "content-type" => "application/json")
      end

      parsed = begin
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise Error, "Anthropic returned #{response.code} and #{response.body.bytesize} bytes of non-JSON"
      end

      raise Error, parsed.dig("error", "message") || "HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      parsed
    end
  end
end
