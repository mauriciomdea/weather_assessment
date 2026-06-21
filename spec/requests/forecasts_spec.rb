require "rails_helper"

RSpec.describe "Forecasts", type: :request do
  before do
    Rails.cache.clear
  end

  describe "GET /forecast" do
    it "displays the selected location forecast in Fahrenheit by default" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call)
        .with(
          location: have_attributes(latitude: 37.318, longitude: -122.0449, display_name: "Cupertino, California, United States"),
          unit: "fahrenheit"
        )
        .and_return(forecast_result(from_cache: false))

      get forecast_path, params: location_params

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<h1>Cupertino</h1>")
      expect(response.body).not_to include("37.3180,")
      expect(response.body).not_to include("America/Los_Angeles")
      expect(response.body).to include("77.0&deg;F")
      expect(response.body).to include("High 86.0&deg;F")
      expect(response.body).to include("Low 68.0&deg;F")
      expect(response.body).not_to include("Weather code")
      expect(response.body).not_to include("Last update")
      expect(response.body).to include("Mauricio Almeida")
      expect(response.body).to include('href="https://github.com/mauriciomdea"')
    end

    it "displays the age of cached forecasts" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call)
        .and_return(forecast_result(from_cache: true, retrieved_at: 7.minutes.ago))

      get forecast_path, params: location_params

      expect(response.body).to include("Last update 7 minutes ago.")
    end

    it "uses cached Fahrenheit data when the display unit changes" do
      forecast_client = instance_double(OpenMeteo::ForecastClient)
      allow(OpenMeteo::ForecastClient).to receive(:new).and_return(forecast_client)
      allow(forecast_client).to receive(:fetch)
        .and_return(forecast_result(from_cache: false, retrieved_at: 4.minutes.ago))

      get forecast_path, params: location_params
      expect(response.body).to include("77.0&deg;F")
      expect(response.body).not_to include("Last update")

      get forecast_path, params: location_params.merge(unit: "celsius")

      expect(response.body).to include("25.0&deg;C")
      expect(response.body).to include("High 30.0&deg;C")
      expect(response.body).to include("Low 20.0&deg;C")
      expect(response.body).to include("Last update 4 minutes ago.")
      expect(forecast_client).to have_received(:fetch)
        .with(latitude: 37.318, longitude: -122.0449, unit: "fahrenheit")
        .once
    end

    it "passes Celsius display preference to the lookup service" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call).and_return(forecast_result(unit: "celsius", from_cache: false))

      get forecast_path, params: location_params.merge(unit: "celsius")

      expect(forecast_lookup).to have_received(:call)
        .with(location: have_attributes(latitude: 37.318, longitude: -122.0449), unit: "celsius")
      expect(response.body).to include("25.0&deg;C")
    end

    it "renders a friendly error when selected location data is invalid" do
      get forecast_path, params: { location: { name: "Invalid" }, unit: "celsius" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Forecast unavailable")
      expect(response.body).to include("Please select a valid location and temperature unit.")
    end

    it "renders a friendly error when forecast lookup fails" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call)
        .and_raise(OpenMeteo::RequestError.new("Open-Meteo forecast request failed", action: "forecast"))

      get forecast_path, params: location_params

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("We could not retrieve the forecast right now. Please try again.")
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
      current_weather_code: 2,
      daily_forecasts: [
        DailyForecast.new(
          date: "2026-06-19",
          temperature_max: unit == "fahrenheit" ? 86.0 : 30.0,
          temperature_min: unit == "fahrenheit" ? 68.0 : 20.0,
          weather_code: 2
        )
      ],
      from_cache:,
      retrieved_at:
    )
  end
end
