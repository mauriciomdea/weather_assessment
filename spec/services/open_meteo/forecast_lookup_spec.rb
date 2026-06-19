require "rails_helper"

RSpec.describe OpenMeteo::ForecastLookup do
  subject(:forecast_lookup) { described_class.new(forecast_client:, cache_store:) }

  let(:forecast_client) { instance_double(OpenMeteo::ForecastClient) }
  let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
  let(:location) do
    LocationResult.new(
      id: 3_451_190,
      name: "Jacarepaguá",
      latitude: -22.9626,
      longitude: -43.3866
    )
  end
  let(:fresh_forecast) do
    ForecastResult.new(
      latitude: -22.9626,
      longitude: -43.3866,
      timezone: "America/Sao_Paulo",
      unit: "celsius",
      current_temperature: 24.8
    )
  end

  describe "#call" do
    it "returns a fresh forecast on cache miss" do
      allow(forecast_client).to receive(:fetch).and_return(fresh_forecast)

      forecast = forecast_lookup.call(location:, unit: "celsius")

      expect(forecast).to have_attributes(
        current_temperature: 24.8,
        from_cache: false
      )
      expect(forecast_client).to have_received(:fetch)
        .with(latitude: -22.9626, longitude: -43.3866, unit: "celsius")
    end

    it "returns a cached forecast on repeated lookup" do
      allow(forecast_client).to receive(:fetch).and_return(fresh_forecast)

      forecast_lookup.call(location:, unit: "celsius")
      cached_forecast = forecast_lookup.call(location:, unit: "celsius")

      expect(cached_forecast).to have_attributes(
        current_temperature: 24.8,
        from_cache: true
      )
      expect(forecast_client).to have_received(:fetch).once
    end

    it "caches Celsius and Fahrenheit forecasts separately" do
      celsius_forecast = ForecastResult.new(latitude: -22.9626, longitude: -43.3866, unit: "celsius", current_temperature: 24.8)
      fahrenheit_forecast = ForecastResult.new(latitude: -22.9626, longitude: -43.3866, unit: "fahrenheit", current_temperature: 76.6)

      allow(forecast_client).to receive(:fetch)
        .with(latitude: -22.9626, longitude: -43.3866, unit: "celsius")
        .and_return(celsius_forecast)
      allow(forecast_client).to receive(:fetch)
        .with(latitude: -22.9626, longitude: -43.3866, unit: "fahrenheit")
        .and_return(fahrenheit_forecast)

      expect(forecast_lookup.call(location:, unit: "celsius").current_temperature).to eq(24.8)
      expect(forecast_lookup.call(location:, unit: "fahrenheit").current_temperature).to eq(76.6)
    end

    it "writes forecasts with a 30 minute expiration" do
      cache_store = instance_double(ActiveSupport::Cache::MemoryStore, read: nil, write: true)
      forecast_lookup = described_class.new(forecast_client:, cache_store:)

      allow(forecast_client).to receive(:fetch).and_return(fresh_forecast)

      forecast_lookup.call(location:, unit: "celsius")

      expect(cache_store).to have_received(:write)
        .with(
          "forecast/location/3451190/celsius",
          have_attributes(from_cache: false),
          expires_in: 30.minutes
        )
    end

    it "rejects unsupported units before reading from cache or fetching forecasts" do
      cache_store = instance_double(ActiveSupport::Cache::MemoryStore)
      forecast_lookup = described_class.new(forecast_client:, cache_store:)

      expect(cache_store).not_to receive(:read)
      expect(forecast_client).not_to receive(:fetch)

      expect do
        forecast_lookup.call(location:, unit: "kelvin")
      end.to raise_error(ArgumentError, 'Unsupported temperature unit: "kelvin"')
    end
  end

  describe "#cache_key" do
    it "uses location id and unit when a location id is available" do
      expect(forecast_lookup.cache_key(location:, unit: "fahrenheit"))
        .to eq("forecast/location/3451190/fahrenheit")
    end

    it "falls back to coordinates and unit when location id is missing" do
      location = LocationResult.new(latitude: 48.8566, longitude: 2.3522)

      expect(forecast_lookup.cache_key(location:, unit: "celsius"))
        .to eq("forecast/coordinates/48.8566,2.3522/celsius")
    end
  end
end
