require "rails_helper"

RSpec.describe Zippopotamus::LocationSearch do
  subject(:location_search) { described_class.new(client:, logger:) }

  let(:client) { instance_double(Zippopotamus::Client) }
  let(:logger) { instance_double(ActiveSupport::Logger, warn: nil) }

  describe "#call" do
    it "returns matching US ZIP code locations from an address" do
      allow(client).to receive(:get)
        .with("/us/95014", action: "zip_code_lookup")
        .and_return(zip_response)

      results = location_search.call("1 Apple Park Way, Cupertino, CA 95014")

      expect(results).to contain_exactly(
        have_attributes(
          id: "US-95014-0",
          display_name: "Cupertino, California, United States",
          latitude: 37.318,
          longitude: -122.0449,
          country: "United States",
          country_code: "US",
          admin1: "California",
          postcodes: [ "95014" ]
        )
      )
    end

    it "supports ZIP+4 input by looking up the five digit ZIP code" do
      allow(client).to receive(:get).and_return(zip_response)

      location_search.call("95014-2083")

      expect(client).to have_received(:get)
        .with("/us/95014", action: "zip_code_lookup")
    end

    it "returns an empty list when input has no US ZIP code" do
      expect(client).not_to receive(:get)

      expect(location_search.call("Jacarepagua")).to eq([])
    end

    it "returns an empty list when the ZIP code is not found" do
      allow(client).to receive(:get)
        .and_raise(Zippopotamus::ResponseError.new("not found", action: "zip_code_lookup", status: "404"))

      expect(location_search.call("00000")).to eq([])
    end

    it "lets client errors surface for the UI layer to handle" do
      allow(client).to receive(:get)
        .and_raise(
          Zippopotamus::RequestError.new(
            "Zippopotam.us zip_code_lookup request failed",
            action: "zip_code_lookup"
          )
        )

      expect { location_search.call("95014") }
        .to raise_error(Zippopotamus::RequestError, "Zippopotam.us zip_code_lookup request failed")
    end

    it "logs sanitized context when ZIP lookup fails" do
      allow(client).to receive(:get)
        .and_raise(
          Zippopotamus::ResponseError.new(
            "Zippopotam.us zip_code_lookup failed with HTTP 503",
            action: "zip_code_lookup",
            status: "503"
          )
        )

      expect do
        location_search.call("1 Infinite Loop, Cupertino, CA 95014")
      end.to raise_error(Zippopotamus::ResponseError)

      expect(logger).to have_received(:warn)
        .with(
          include(
            "provider=zippopotamus",
            "action=zip_code_lookup",
            "zip_code_present=true",
            "error_class=Zippopotamus::ResponseError",
            "status=503"
          )
        )
      expect(logger).not_to have_received(:warn).with(include("Infinite Loop"))
    end
  end

  def zip_response
    {
      "post code" => "95014",
      "country" => "United States",
      "country abbreviation" => "US",
      "places" => [
        {
          "place name" => "Cupertino",
          "longitude" => "-122.0449",
          "state" => "California",
          "state abbreviation" => "CA",
          "latitude" => "37.318"
        }
      ]
    }
  end
end
