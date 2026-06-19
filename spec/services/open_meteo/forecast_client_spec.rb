require "rails_helper"

RSpec.describe OpenMeteo::ForecastClient do
  subject(:forecast_client) { described_class.new(client:) }

  let(:client) { instance_double(OpenMeteo::Client) }

  describe "#fetch" do
    it "fetches forecast data in Celsius" do
      allow(client).to receive(:get).and_return(api_response)

      forecast = forecast_client.fetch(latitude: -22.96, longitude: -43.38, unit: "celsius")

      expect(client).to have_received(:get)
        .with(
          "/v1/forecast",
          params: {
            latitude: -22.96,
            longitude: -43.38,
            current: "temperature_2m,weather_code",
            daily: "temperature_2m_max,temperature_2m_min,weather_code",
            temperature_unit: "celsius",
            timezone: "auto",
            forecast_days: 7
          },
          action: "forecast"
        )

      expect(forecast).to have_attributes(
        unit: "celsius",
        current_temperature: 24.8,
        current_weather_code: 2
      )
    end

    it "fetches forecast data in Fahrenheit" do
      allow(client).to receive(:get).and_return(api_response)

      forecast = forecast_client.fetch(latitude: 40.71, longitude: -74.01, unit: "fahrenheit")

      expect(client).to have_received(:get)
        .with(
          "/v1/forecast",
          params: hash_including(temperature_unit: "fahrenheit"),
          action: "forecast"
        )
      expect(forecast.unit).to eq("fahrenheit")
    end

    it "allows the forecast length to be customized" do
      allow(client).to receive(:get).and_return(api_response)

      forecast_client.fetch(latitude: 48.85, longitude: 2.35, unit: "celsius", forecast_days: 10)

      expect(client).to have_received(:get)
        .with(
          "/v1/forecast",
          params: hash_including(forecast_days: 10),
          action: "forecast"
        )
    end

    it "rejects unsupported temperature units before making a request" do
      expect(client).not_to receive(:get)

      expect do
        forecast_client.fetch(latitude: -22.96, longitude: -43.38, unit: "kelvin")
      end.to raise_error(ArgumentError, 'Unsupported temperature unit: "kelvin"')
    end

    it "lets client errors surface for the UI layer to handle" do
      allow(client).to receive(:get)
        .and_raise(OpenMeteo::ResponseError.new("Open-Meteo forecast failed with HTTP 500", action: "forecast", status: "500"))

      expect do
        forecast_client.fetch(latitude: -22.96, longitude: -43.38, unit: "celsius")
      end.to raise_error(OpenMeteo::ResponseError, "Open-Meteo forecast failed with HTTP 500")
    end
  end

  def api_response
    {
      "latitude" => -22.96,
      "longitude" => -43.38,
      "timezone" => "America/Sao_Paulo",
      "current" => {
        "time" => "2026-06-19T12:00",
        "temperature_2m" => 24.8,
        "weather_code" => 2
      },
      "daily" => {
        "time" => [ "2026-06-19" ],
        "temperature_2m_max" => [ 29.1 ],
        "temperature_2m_min" => [ 20.4 ],
        "weather_code" => [ 2 ]
      }
    }
  end
end
