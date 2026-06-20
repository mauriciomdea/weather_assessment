require "rails_helper"

RSpec.describe "Forecasts", type: :request do
  before do
    Rails.cache.clear
  end

  describe "GET /forecast" do
    it "displays the selected location forecast" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call)
        .with(
          location: have_attributes(latitude: -22.9626, longitude: -43.3866, display_name: "Jacarepaguá, Rio de Janeiro, Brazil"),
          unit: "celsius"
        )
        .and_return(forecast_result(from_cache: false))

      get forecast_path, params: location_params.merge(unit: "celsius")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Jacarepaguá, Rio de Janeiro, Brazil")
      expect(response.body).to include("24.8&deg;C")
      expect(response.body).to include("High 29.1&deg;C")
      expect(response.body).to include("Low 20.4&deg;C")
      expect(response.body).to include("Forecast retrieved from Open-Meteo.")
    end

    it "displays an indicator when the forecast comes from cache" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call).and_return(forecast_result(from_cache: true))

      get forecast_path, params: location_params.merge(unit: "celsius")

      expect(response.body).to include("Forecast served from cache.")
    end

    it "serves repeated forecast requests from Rails cache" do
      forecast_client = instance_double(OpenMeteo::ForecastClient)
      allow(OpenMeteo::ForecastClient).to receive(:new).and_return(forecast_client)
      allow(forecast_client).to receive(:fetch).and_return(forecast_result(from_cache: false))

      get forecast_path, params: location_params.merge(unit: "celsius")
      expect(response.body).to include("Forecast retrieved from Open-Meteo.")

      get forecast_path, params: location_params.merge(unit: "celsius")
      expect(response.body).to include("Forecast served from cache.")
      expect(forecast_client).to have_received(:fetch).once
    end

    it "passes Fahrenheit preference to the lookup service" do
      forecast_lookup = instance_double(OpenMeteo::ForecastLookup)
      allow(OpenMeteo::ForecastLookup).to receive(:new).and_return(forecast_lookup)
      allow(forecast_lookup).to receive(:call).and_return(forecast_result(unit: "fahrenheit", from_cache: false))

      get forecast_path, params: location_params.merge(unit: "fahrenheit")

      expect(forecast_lookup).to have_received(:call)
        .with(location: have_attributes(latitude: -22.9626, longitude: -43.3866), unit: "fahrenheit")
      expect(response.body).to include("24.8&deg;F")
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

      get forecast_path, params: location_params.merge(unit: "celsius")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("We could not retrieve the forecast right now. Please try again.")
    end
  end

  def location_params
    {
      location: {
        id: "3451190",
        name: "Jacarepaguá",
        latitude: "-22.9626",
        longitude: "-43.3866",
        country: "Brazil",
        country_code: "BR",
        admin1: "Rio de Janeiro",
        admin2: "Rio de Janeiro",
        timezone: "America/Sao_Paulo"
      }
    }
  end

  def forecast_result(unit: "celsius", from_cache:)
    ForecastResult.new(
      latitude: -22.9626,
      longitude: -43.3866,
      timezone: "America/Sao_Paulo",
      unit:,
      current_temperature: 24.8,
      current_weather_code: 2,
      daily_forecasts: [
        DailyForecast.new(date: "2026-06-19", temperature_max: 29.1, temperature_min: 20.4, weather_code: 2)
      ],
      from_cache:
    )
  end
end
