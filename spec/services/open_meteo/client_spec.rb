require "rails_helper"

RSpec.describe OpenMeteo::Client do
  subject(:client) { described_class.new(base_url:, logger:) }

  let(:base_url) { "https://example.test" }
  let(:logger) { instance_double(ActiveSupport::Logger, warn: nil) }

  describe "#get" do
    it "returns parsed JSON for a successful response" do
      stub_request(:get, "https://example.test/v1/forecast?latitude=-22.9&longitude=-43.3")
        .to_return(status: 200, body: { "current" => { "temperature_2m" => 27.1 } }.to_json)

      response = client.get(
        "/v1/forecast",
        params: { latitude: -22.9, longitude: -43.3 },
        action: "forecast"
      )

      expect(response).to eq("current" => { "temperature_2m" => 27.1 })
    end

    it "raises a response error and logs when the API returns a non-success status" do
      stub_request(:get, "https://example.test/v1/forecast")
        .to_return(status: 503, body: "service unavailable")

      expect do
        client.get("/v1/forecast", action: "forecast")
      end.to raise_error(OpenMeteo::ResponseError, "Open-Meteo forecast failed with HTTP 503")

      expect(logger).to have_received(:warn)
        .with(include("provider=open_meteo", "action=forecast", "path=/v1/forecast", "status=503"))
    end

    it "raises a parse error and logs when the API returns invalid JSON" do
      stub_request(:get, "https://example.test/v1/forecast")
        .to_return(status: 200, body: "not-json")

      expect do
        client.get("/v1/forecast", action: "forecast")
      end.to raise_error(OpenMeteo::ParseError, "Open-Meteo forecast returned invalid JSON")

      expect(logger).to have_received(:warn)
        .with(include("provider=open_meteo", "action=forecast", "path=/v1/forecast", "error_class=JSON::ParserError"))
    end

    it "raises a request error and logs when the request cannot be completed" do
      stub_request(:get, "https://example.test/v1/forecast").to_timeout

      expect do
        client.get("/v1/forecast", action: "forecast")
      end.to raise_error(OpenMeteo::RequestError, "Open-Meteo forecast request failed")

      expect(logger).to have_received(:warn)
        .with(include("provider=open_meteo", "action=forecast", "path=/v1/forecast", "status=unavailable"))
    end
  end
end
