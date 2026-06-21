require "rails_helper"

RSpec.describe "Forecasts", type: :request do
  before do
    Rails.cache.clear
  end

  describe "GET /forecast" do
    it "requests a Fahrenheit forecast by default for the selected location" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call)
        .with(
          location: have_attributes(latitude: 37.318, longitude: -122.0449),
          unit: "fahrenheit"
        )
        .and_return(forecast_result(from_cache: false))

      get forecast_path, params: location_params

      expect(response).to have_http_status(:ok)
    end

    it "passes Celsius display preference to the lookup service" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call)
        .and_return(forecast_result(unit: "celsius", from_cache: false))

      get forecast_path, params: location_params.merge(unit: "celsius")

      expect(response).to have_http_status(:ok)
      expect(forecast_lookup).to have_received(:call)
        .with(location: have_attributes(latitude: 37.318, longitude: -122.0449), unit: "celsius")
    end

    it "uses cached Fahrenheit data when the display unit changes" do
      forecast_client = instance_double(OpenMeteo::ForecastClient)
      allow(OpenMeteo::ForecastClient).to receive(:new).and_return(forecast_client)
      allow(forecast_client).to receive(:fetch)
        .and_return(forecast_result(from_cache: false, retrieved_at: 4.minutes.ago))

      get forecast_path, params: location_params
      get forecast_path, params: location_params.merge(unit: "celsius")

      expect(response).to have_http_status(:ok)
      expect(forecast_client).to have_received(:fetch)
        .with(latitude: 37.318, longitude: -122.0449, unit: "fahrenheit")
        .once
    end

    it "handles invalid selected location data" do
      get forecast_path, params: { location: { name: "Invalid" }, unit: "celsius" }

      expect(response).to have_http_status(:ok)
    end

    it "handles forecast lookup failures" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call)
        .and_raise(OpenMeteo::RequestError.new("Open-Meteo forecast request failed", action: "forecast"))

      get forecast_path, params: location_params

      expect(response).to have_http_status(:ok)
    end
  end

  def location_params
    {
      location: {
        id: "US-95014-0",
        name: "Cupertino",
        latitude: "37.318",
        longitude: "-122.0449",
        country: "United States",
        country_code: "US",
        admin1: "California"
      }
    }
  end

  def forecast_result(unit: "fahrenheit", from_cache:, retrieved_at: Time.current)
    ForecastResult.new(
      latitude: 37.318,
      longitude: -122.0449,
      timezone: "America/Los_Angeles",
      unit:,
      current_temperature: unit == "fahrenheit" ? 77.0 : 25.0,
      daily_forecasts: [
        DailyForecast.new(
          date: "2026-06-19",
          temperature_max: unit == "fahrenheit" ? 86.0 : 30.0,
          temperature_min: unit == "fahrenheit" ? 68.0 : 20.0
        )
      ],
      from_cache:,
      retrieved_at:
    )
  end
end
