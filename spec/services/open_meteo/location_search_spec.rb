require "rails_helper"

RSpec.describe OpenMeteo::LocationSearch do
  subject(:location_search) { described_class.new(client:) }

  let(:client) { instance_double(OpenMeteo::Client) }

  describe "#call" do
    it "returns matching global locations for a search term" do
      allow(client).to receive(:get)
        .with(
          "/v1/search",
          params: {
            name: "Jacarapagua",
            count: 10,
            language: "en",
            format: "json"
          },
          action: "geocoding"
        )
        .and_return(
          "results" => [
            {
              "id" => 3_451_190,
              "name" => "Jacarepaguá",
              "latitude" => -22.9626,
              "longitude" => -43.3866,
              "country" => "Brazil",
              "country_code" => "BR",
              "admin1" => "Rio de Janeiro",
              "admin2" => "Rio de Janeiro",
              "timezone" => "America/Sao_Paulo"
            }
          ]
        )

      results = location_search.call(" Jacarapagua ")

      expect(results).to contain_exactly(
        have_attributes(
          id: 3_451_190,
          display_name: "Jacarepaguá, Rio de Janeiro, Brazil",
          latitude: -22.9626,
          longitude: -43.3866,
          timezone: "America/Sao_Paulo"
        )
      )
    end

    it "returns an empty list when Open-Meteo has no matches" do
      allow(client).to receive(:get).and_return({})

      expect(location_search.call("Unknown Atlantis")).to eq([])
    end

    it "does not call the API for blank or one-character searches" do
      expect(client).not_to receive(:get)

      expect(location_search.call(" ")).to eq([])
      expect(location_search.call("a")).to eq([])
    end

    it "allows result count and language to be customized" do
      allow(client).to receive(:get).and_return("results" => [])

      location_search.call("Paris", count: 5, language: "pt")

      expect(client).to have_received(:get)
        .with(
          "/v1/search",
          params: {
            name: "Paris",
            count: 5,
            language: "pt",
            format: "json"
          },
          action: "geocoding"
        )
    end

    it "lets client errors surface for the UI layer to handle" do
      allow(client).to receive(:get)
        .and_raise(OpenMeteo::RequestError.new("Open-Meteo geocoding request failed", action: "geocoding"))

      expect { location_search.call("London") }
        .to raise_error(OpenMeteo::RequestError, "Open-Meteo geocoding request failed")
    end
  end
end
