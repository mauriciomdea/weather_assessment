require "rails_helper"

RSpec.describe "Locations", type: :request do
  describe "GET /" do
    it "renders the US ZIP code search form" do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Weather Forecast Assessment")
      expect(response.body).to include("Enter a US ZIP code to search forecast locations.")
      expect(response.body).to include("Celsius")
      expect(response.body).to include("Fahrenheit")
    end
  end

  describe "GET /locations" do
    it "renders an empty state when the query has no ZIP code" do
      location_search = instance_double(Zippopotamus::LocationSearch, call: [])
      allow(Zippopotamus::LocationSearch).to receive(:new).and_return(location_search)

      get locations_path, params: { query: "Jacarepagua" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No matching US ZIP code found for "Jacarepagua".')
    end

    it "renders matching US ZIP code locations" do
      location_search = instance_double(Zippopotamus::LocationSearch)
      allow(Zippopotamus::LocationSearch).to receive(:new).and_return(location_search)
      allow(location_search).to receive(:call)
        .with("1 Apple Park Way, Cupertino, CA 95014")
        .and_return(
          [
            LocationResult.new(
              name: "Cupertino",
              admin1: "California",
              country: "United States",
              latitude: 37.318,
              longitude: -122.0449,
              postcodes: [ "95014" ]
            )
          ]
        )

      get locations_path, params: { query: "1 Apple Park Way, Cupertino, CA 95014" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Matching Locations")
      expect(response.body).to include("Cupertino, California, United States")
      expect(response.body).to include("View forecast")
    end

    it "renders an empty state when no ZIP code matches" do
      location_search = instance_double(Zippopotamus::LocationSearch, call: [])
      allow(Zippopotamus::LocationSearch).to receive(:new).and_return(location_search)

      get locations_path, params: { query: "00000" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('No matching US ZIP code found for "00000".')
    end

    it "renders a friendly error when location search fails" do
      location_search = instance_double(Zippopotamus::LocationSearch)
      allow(Zippopotamus::LocationSearch).to receive(:new).and_return(location_search)
      allow(location_search).to receive(:call)
        .and_raise(
          Zippopotamus::RequestError.new(
            "Zippopotam.us zip_code_lookup request failed",
            action: "zip_code_lookup"
          )
        )

      get locations_path, params: { query: "95014" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("We could not retrieve matching locations right now. Please try again.")
    end

    it "wraps results in the Turbo frame used by progressive search" do
      location_search = instance_double(Zippopotamus::LocationSearch, call: [])
      allow(Zippopotamus::LocationSearch).to receive(:new).and_return(location_search)

      get locations_path, params: { query: "95014" }, headers: { "Turbo-Frame" => "location_results" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<turbo-frame id="location_results">')
    end
  end
end
