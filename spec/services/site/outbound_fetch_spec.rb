require "rails_helper"

# This is the only place the application fetches a URL chosen by the AI rather
# than by a developer, so these are the specs for a security boundary, not for a
# feature. Each one stands for an attack that works against an unguarded fetch.
RSpec.describe Site::OutboundFetch do
  def refuse(url) = expect { described_class.call(url) }.to raise_error(described_class::Refused)

  describe "addresses it must never fetch" do
    it "refuses anything but https" do
      refuse "http://example.com/"
      refuse "file:///etc/passwd"
      refuse "gopher://example.com/"
    end

    it "refuses the cloud metadata endpoint, which is the whole point of the guard" do
      refuse "https://169.254.169.254/latest/meta-data/iam/security-credentials/"
    end

    it "refuses loopback, by literal and by name" do
      refuse "https://127.0.0.1:3000/"
      refuse "https://localhost:5432/"
      refuse "https://[::1]/"
    end

    it "refuses the private ranges" do
      refuse "https://10.0.0.5/"
      refuse "https://172.16.0.1/"
      refuse "https://192.168.1.1/"
      refuse "https://[fd00::1]/"
    end

    it "refuses carrier-grade NAT, where some clouds put their metadata" do
      refuse "https://100.100.100.200/"
    end

    it "refuses credentials in the URL, which would be sent to the host" do
      refuse "https://user:password@example.com/"
    end

    it "refuses a host that resolves to nothing" do
      refuse "https://metadata.google.internal/"
    end

    it "refuses nonsense" do
      refuse "not a url"
      refuse "https://"
    end
  end

  # The bug that people actually ship. The first address is public and passes
  # every check; the redirect is where it goes private.
  describe "redirects" do
    def respond_with(*responses)
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:request).and_return(*responses)
    end

    def redirect_to(location)
      Net::HTTPFound.new("1.1", "302", "Found").tap do |r|
        allow(r).to receive(:[]).with("location").and_return(location)
      end
    end

    def body(text, type = "application/json")
      Net::HTTPOK.new("1.1", "200", "OK").tap do |r|
        allow(r).to receive(:[]).with("content-type").and_return(type)
        allow(r).to receive(:body).and_return(text)
      end
    end

    it "re-checks the address after a redirect" do
      respond_with(redirect_to("https://127.0.0.1/secrets"))
      refuse "https://example.com/start"
    end

    it "re-checks after a redirect to the metadata endpoint" do
      respond_with(redirect_to("https://169.254.169.254/latest/meta-data/"))
      refuse "https://example.com/start"
    end

    it "refuses a redirect that downgrades to http" do
      respond_with(redirect_to("http://example.com/plain"))
      refuse "https://example.com/start"
    end

    it "follows a redirect to another public address" do
      respond_with(redirect_to("https://example.org/moved"), body('{"ok":true}'))
      result = described_class.call("https://example.com/start")
      expect(result.body).to eq('{"ok":true}')
      expect(result.url).to eq("https://example.org/moved")
    end

    it "gives up rather than looping forever" do
      respond_with(*Array.new(6) { redirect_to("https://example.org/again") })
      refuse "https://example.com/start"
    end
  end

  describe "what comes back" do
    def responds(type, text)
      http = instance_double(Net::HTTP)
      allow(Net::HTTP).to receive(:start).and_yield(http)
      response = Net::HTTPOK.new("1.1", "200", "OK")
      allow(response).to receive(:[]).with("content-type").and_return(type)
      allow(response).to receive(:body).and_return(text)
      allow(http).to receive(:request).and_return(response)
    end

    it "refuses a type that is not text or data" do
      responds("application/octet-stream", "\x00\x01")
      refuse "https://example.com/thing.bin"
    end

    it "refuses a body over the size cap" do
      responds("text/html", "x" * (described_class::MAX_BYTES + 1))
      refuse "https://example.com/huge"
    end

    it "accepts JSON served as text/html, which is what ChurchTrac does" do
      responds("text/html; charset=utf-8", '[{"title":"Vespers"}]')
      expect(described_class.call("https://example.com/feed").body).to include("Vespers")
    end

    it "scrubs invalid bytes rather than raising later" do
      responds("text/plain", "caf\xC3\xA9 \xFF")
      expect(described_class.call("https://example.com/t").body).to be_valid_encoding
    end
  end
end
