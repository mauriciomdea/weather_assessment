require "rails_helper"

RSpec.describe Zippopotamus::Client do
  subject(:client) { described_class.new(base_url:, logger:) }

  let(:base_url) { "https://example.test" }
  let(:logger) { instance_double(ActiveSupport::Logger, warn: nil) }

  describe "#get" do
    it "returns parsed JSON for a successful response" do
      stub_request(:get, "https://example.test/us/90210")
        .to_return(status: 200, body: { "post code" => "90210" }.to_json)

      expect(client.get("/us/90210", action: "zip_code_lookup"))
        .to eq("post code" => "90210")
    end

    it "raises a response error and logs when the API returns a non-success status" do
      stub_request(:get, "https://example.test/us/00000")
        .to_return(status: 404, body: "not found")

      expect do
        client.get("/us/00000", action: "zip_code_lookup")
      end.to raise_error(Zippopotamus::ResponseError, "Zippopotam.us zip_code_lookup failed with HTTP 404")

      expect(logger).to have_received(:warn)
        .with(include("provider=zippopotamus", "action=zip_code_lookup", "path=/us/00000", "status=404"))
    end

    it "raises a parse error and logs when the API returns invalid JSON" do
      stub_request(:get, "https://example.test/us/90210")
        .to_return(status: 200, body: "not-json")

      expect do
        client.get("/us/90210", action: "zip_code_lookup")
      end.to raise_error(Zippopotamus::ParseError, "Zippopotam.us zip_code_lookup returned invalid JSON")

      expect(logger).to have_received(:warn)
        .with(include("provider=zippopotamus", "action=zip_code_lookup", "error_class=JSON::ParserError"))
    end

    it "raises a request error and logs when the request cannot be completed" do
      stub_request(:get, "https://example.test/us/90210").to_timeout

      expect do
        client.get("/us/90210", action: "zip_code_lookup")
      end.to raise_error(Zippopotamus::RequestError, "Zippopotam.us zip_code_lookup request failed")

      expect(logger).to have_received(:warn)
        .with(include("provider=zippopotamus", "action=zip_code_lookup", "status=unavailable"))
    end
  end
end
