require "rails_helper"

RSpec.describe "Locations", type: :request do
  describe "GET /" do
    it "renders the location search form" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weather Assessment")
      expect(response.body).to include("Start typing to search global locations.")
      expect(response.body).to include("Celsius")
      expect(response.body).to include("Fahrenheit")
    end
  end

  describe "GET /locations" do
    it "does not search when the query is shorter than two characters" do
      expect(OpenMeteo::LocationSearch).not_to receive(:new)

      get locations_path, params: { query: "a" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Enter at least two characters to search.")
    end

    it "renders matching global locations" do
      location_search = instance_double(OpenMeteo::LocationSearch)
      allow(OpenMeteo::LocationSearch).to receive(:new).and_return(location_search)
      allow(location_search).to receive(:call)
        .with("Jacarapagua")
        .and_return(
          [
            LocationResult.new(
              name: "Jacarepaguá",
              admin2: "Rio de Janeiro",
              admin1: "Rio de Janeiro",
              country: "Brazil",
              latitude: -22.9626,
              longitude: -43.3866,
              timezone: "America/Sao_Paulo"
            )
          ]
        )

      get locations_path, params: { query: "Jacarapagua" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Matching Locations")
      expect(response.body).to include("Jacarepaguá, Rio de Janeiro, Brazil")
      expect(response.body).to include("America/Sao_Paulo")
      expect(response.body).to include("View forecast")
    end

    it "renders an empty state when no locations match" do
      location_search = instance_double(OpenMeteo::LocationSearch, call: [])
      allow(OpenMeteo::LocationSearch).to receive(:new).and_return(location_search)

      get locations_path, params: { query: "Unknown Atlantis" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No matching locations found for "Unknown Atlantis".')
    end

    it "renders a friendly error when location search fails" do
      location_search = instance_double(OpenMeteo::LocationSearch)
      allow(OpenMeteo::LocationSearch).to receive(:new).and_return(location_search)
      allow(location_search).to receive(:call)
        .and_raise(OpenMeteo::RequestError.new("Open-Meteo geocoding request failed", action: "geocoding"))

      get locations_path, params: { query: "London" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("We could not retrieve matching locations right now. Please try again.")
    end

    it "wraps results in the Turbo frame used by progressive search" do
      location_search = instance_double(OpenMeteo::LocationSearch, call: [])
      allow(OpenMeteo::LocationSearch).to receive(:new).and_return(location_search)

      get locations_path, params: { query: "Paris" }, headers: { "Turbo-Frame" => "location_results" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="location_results">')
    end
  end
end
