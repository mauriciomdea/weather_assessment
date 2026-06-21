require "rails_helper"

RSpec.describe "Locations", type: :request do
  describe "GET /" do
    it "responds successfully" do
      get root_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /locations" do
    it "searches locations with the submitted query" do
      location_search = instance_double(Zippopotamus::LocationSearch, call: [])
      allow(Zippopotamus::LocationSearch).to receive(:new).and_return(location_search)

      get locations_path, params: { query: "1 Apple Park Way, Cupertino, CA 95014" }

      expect(response).to have_http_status(:ok)
      expect(location_search).to have_received(:call)
        .with("1 Apple Park Way, Cupertino, CA 95014")
    end

    it "handles searches with no matching locations" do
      location_search = instance_double(Zippopotamus::LocationSearch, call: [])
      allow(Zippopotamus::LocationSearch).to receive(:new).and_return(location_search)

      get locations_path, params: { query: "00000" }

      expect(response).to have_http_status(:ok)
    end

    it "handles location search failures" do
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
    end
  end
end
