require "rails_helper"

RSpec.describe LocationResult do
  describe ".from_api" do
    it "normalizes Open-Meteo geocoding attributes" do
      location = described_class.from_api(
        "id" => 3_451_190,
        "name" => "Jacarepaguá",
        "latitude" => -22.9626,
        "longitude" => -43.3866,
        "country" => "Brazil",
        "country_code" => "BR",
        "admin1" => "Rio de Janeiro",
        "admin2" => "Rio de Janeiro",
        "timezone" => "America/Sao_Paulo",
        "population" => 100_000,
        "postcodes" => [ "22775" ]
      )

      expect(location).to have_attributes(
        id: 3_451_190,
        name: "Jacarepaguá",
        latitude: -22.9626,
        longitude: -43.3866,
        country: "Brazil",
        country_code: "BR",
        admin1: "Rio de Janeiro",
        admin2: "Rio de Janeiro",
        timezone: "America/Sao_Paulo",
        population: 100_000,
        postcodes: [ "22775" ]
      )
    end

    it "defaults missing postcodes to an empty list" do
      location = described_class.from_api("name" => "Berlin")

      expect(location.postcodes).to eq([])
    end
  end

  describe "#display_name" do
    it "builds a readable global location label without repeated blank parts" do
      location = described_class.new(
        name: "Jacarepaguá",
        admin2: "Rio de Janeiro",
        admin1: "Rio de Janeiro",
        country: "Brazil"
      )

      expect(location.display_name).to eq("Jacarepaguá, Rio de Janeiro, Brazil")
    end
  end
end
