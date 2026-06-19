require "rails_helper"

RSpec.describe ForecastResult do
  describe ".from_api" do
    it "normalizes current and daily Open-Meteo forecast data" do
      forecast = described_class.from_api(api_response, unit: "celsius")

      expect(forecast).to have_attributes(
        latitude: -22.96,
        longitude: -43.38,
        timezone: "America/Sao_Paulo",
        unit: "celsius",
        current_temperature: 24.8,
        current_weather_code: 2,
        current_time: "2026-06-19T12:00",
        from_cache: false
      )

      expect(forecast.daily_forecasts).to contain_exactly(
        have_attributes(date: "2026-06-19", temperature_max: 29.1, temperature_min: 20.4, weather_code: 2),
        have_attributes(date: "2026-06-20", temperature_max: 27.6, temperature_min: 19.8, weather_code: 61)
      )
    end

    it "uses an empty daily forecast list when daily data is missing" do
      forecast = described_class.from_api({}, unit: "fahrenheit")

      expect(forecast.daily_forecasts).to eq([])
    end
  end

  describe ".normalize_unit" do
    it "accepts Celsius and Fahrenheit case-insensitively" do
      expect(described_class.normalize_unit(" Celsius ")).to eq("celsius")
      expect(described_class.normalize_unit("FAHRENHEIT")).to eq("fahrenheit")
    end

    it "rejects unsupported units" do
      expect { described_class.normalize_unit("kelvin") }
        .to raise_error(ArgumentError, 'Unsupported temperature unit: "kelvin"')
    end
  end

  describe "#temperature_unit_symbol" do
    it "returns C for Celsius and F for Fahrenheit" do
      expect(described_class.new(unit: "celsius").temperature_unit_symbol).to eq("C")
      expect(described_class.new(unit: "fahrenheit").temperature_unit_symbol).to eq("F")
    end
  end

  describe "#with_cache_status" do
    it "returns a copy with the requested cache status" do
      forecast = described_class.new(
        latitude: -22.96,
        longitude: -43.38,
        timezone: "America/Sao_Paulo",
        unit: "celsius",
        current_temperature: 24.8,
        daily_forecasts: [ DailyForecast.new(date: "2026-06-19") ]
      )

      cached_forecast = forecast.with_cache_status(true)

      expect(cached_forecast).to have_attributes(
        latitude: -22.96,
        longitude: -43.38,
        timezone: "America/Sao_Paulo",
        unit: "celsius",
        current_temperature: 24.8,
        from_cache: true
      )
      expect(cached_forecast.daily_forecasts).to eq(forecast.daily_forecasts)
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
        "time" => [ "2026-06-19", "2026-06-20" ],
        "temperature_2m_max" => [ 29.1, 27.6 ],
        "temperature_2m_min" => [ 20.4, 19.8 ],
        "weather_code" => [ 2, 61 ]
      }
    }
  end
end
