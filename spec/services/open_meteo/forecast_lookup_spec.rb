require "rails_helper"

RSpec.describe OpenMeteo::ForecastLookup do
  subject(:forecast_lookup) { described_class.new(forecast_client:, cache_store:, logger:) }

  let(:forecast_client) { instance_double(OpenMeteo::ForecastClient) }
  let(:cache_store) { ActiveSupport::Cache::MemoryStore.new }
  let(:logger) { instance_double(ActiveSupport::Logger, warn: nil) }
  let(:location) do
    LocationResult.new(
      id: 3_451_190,
      name: "Jacarepagua",
      latitude: -22.9626,
      longitude: -43.3866
    )
  end
  let(:fresh_forecast) do
    ForecastResult.new(
      latitude: -22.9626,
      longitude: -43.3866,
      timezone: "America/Sao_Paulo",
      unit: "fahrenheit",
      current_temperature: 77.0,
      daily_forecasts: [
        DailyForecast.new(date: "2026-06-19", temperature_max: 86.0, temperature_min: 68.0)
      ]
    )
  end

  describe "#call" do
    it "returns a fresh Fahrenheit forecast on cache miss" do
      allow(forecast_client).to receive(:fetch).and_return(fresh_forecast)

      forecast = forecast_lookup.call(location:, unit: "fahrenheit")

      expect(forecast).to have_attributes(
        unit: "fahrenheit",
        current_temperature: 77.0,
        from_cache: false
      )
      expect(forecast_client).to have_received(:fetch)
        .with(latitude: -22.9626, longitude: -43.3866, unit: "fahrenheit")
    end

    it "converts a fresh Fahrenheit forecast when Celsius is requested" do
      allow(forecast_client).to receive(:fetch).and_return(fresh_forecast)

      forecast = forecast_lookup.call(location:, unit: "celsius")

      expect(forecast).to have_attributes(
        unit: "celsius",
        current_temperature: 25.0,
        from_cache: false
      )
      expect(forecast.daily_forecasts).to contain_exactly(
        have_attributes(temperature_max: 30.0, temperature_min: 20.0)
      )
      expect(forecast_client).to have_received(:fetch)
        .with(latitude: -22.9626, longitude: -43.3866, unit: "fahrenheit")
    end

    it "returns a cached forecast on repeated lookup" do
      allow(forecast_client).to receive(:fetch).and_return(fresh_forecast)

      forecast_lookup.call(location:, unit: "fahrenheit")
      cached_forecast = forecast_lookup.call(location:, unit: "fahrenheit")

      expect(cached_forecast).to have_attributes(
        current_temperature: 77.0,
        from_cache: true,
        retrieved_at: fresh_forecast.retrieved_at
      )
      expect(forecast_client).to have_received(:fetch).once
    end

    it "uses the cached Fahrenheit forecast when the display unit changes" do
      allow(forecast_client).to receive(:fetch).and_return(fresh_forecast)

      forecast_lookup.call(location:, unit: "fahrenheit")
      converted_forecast = forecast_lookup.call(location:, unit: "celsius")

      expect(converted_forecast).to have_attributes(
        unit: "celsius",
        current_temperature: 25.0,
        from_cache: true
      )
      expect(forecast_client).to have_received(:fetch).once
    end

    it "writes forecasts with a 30 minute expiration" do
      cache_store = instance_double(ActiveSupport::Cache::MemoryStore, read: nil, write: true)
      forecast_lookup = described_class.new(forecast_client:, cache_store:)

      allow(forecast_client).to receive(:fetch).and_return(fresh_forecast)

      forecast_lookup.call(location:, unit: "celsius")

      expect(cache_store).to have_received(:write)
        .with(
          "forecast/location/3451190",
          have_attributes(unit: "fahrenheit", from_cache: false),
          expires_in: 30.minutes
        )
    end

    it "rejects unsupported units before reading from cache or fetching forecasts" do
      cache_store = instance_double(ActiveSupport::Cache::MemoryStore)
      forecast_lookup = described_class.new(forecast_client:, cache_store:, logger:)

      expect(cache_store).not_to receive(:read)
      expect(forecast_client).not_to receive(:fetch)

      expect do
        forecast_lookup.call(location:, unit: "kelvin")
      end.to raise_error(ArgumentError, 'Unsupported temperature unit: "kelvin"')
    end

    it "logs location, fetch unit, and display unit context when forecast retrieval fails" do
      allow(forecast_client).to receive(:fetch)
        .and_raise(
          OpenMeteo::ResponseError.new(
            "Open-Meteo forecast failed with HTTP 429",
            action: "forecast",
            status: "429"
          )
        )

      expect do
        forecast_lookup.call(location:, unit: "celsius")
      end.to raise_error(OpenMeteo::ResponseError)

      expect(logger).to have_received(:warn)
        .with(
          include(
            "provider=open_meteo",
            "action=forecast",
            "location=id:3451190",
            "fetch_unit=fahrenheit",
            "display_unit=celsius",
            "error_class=OpenMeteo::ResponseError",
            "status=429"
          )
        )
    end
  end

  describe "#cache_key" do
    it "uses location id when a location id is available" do
      expect(forecast_lookup.cache_key(location:))
        .to eq("forecast/location/3451190")
    end

    it "falls back to coordinates when location id is missing" do
      location = LocationResult.new(latitude: 48.8566, longitude: 2.3522)

      expect(forecast_lookup.cache_key(location:))
        .to eq("forecast/coordinates/48.8566,2.3522")
    end
  end
end
