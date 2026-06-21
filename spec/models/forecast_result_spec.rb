require "rails_helper"

RSpec.describe ForecastResult do
  include ActiveSupport::Testing::TimeHelpers

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
        from_cache: false,
        retrieved_at: be_present
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

  describe "#with_unit" do
    it "converts Fahrenheit forecast temperatures to Celsius" do
      forecast = described_class.new(
        latitude: -22.96,
        longitude: -43.38,
        timezone: "America/Sao_Paulo",
        unit: "fahrenheit",
        current_temperature: 77.0,
        daily_forecasts: [
          DailyForecast.new(date: "2026-06-19", temperature_max: 86.0, temperature_min: 68.0, weather_code: 2)
        ],
        from_cache: true,
        retrieved_at: Time.zone.local(2026, 6, 19, 12, 0)
      )

      converted_forecast = forecast.with_unit("celsius")

      expect(converted_forecast).to have_attributes(
        unit: "celsius",
        current_temperature: 25.0,
        from_cache: true,
        retrieved_at: Time.zone.local(2026, 6, 19, 12, 0)
      )
      expect(converted_forecast.daily_forecasts).to contain_exactly(
        have_attributes(date: "2026-06-19", temperature_max: 30.0, temperature_min: 20.0, weather_code: 2)
      )
    end

    it "converts Celsius forecast temperatures to Fahrenheit" do
      forecast = described_class.new(
        unit: "celsius",
        current_temperature: 25.0,
        daily_forecasts: [
          DailyForecast.new(date: "2026-06-19", temperature_max: 30.0, temperature_min: 20.0)
        ]
      )

      converted_forecast = forecast.with_unit("fahrenheit")

      expect(converted_forecast.current_temperature).to eq(77.0)
      expect(converted_forecast.daily_forecasts.first).to have_attributes(
        temperature_max: 86.0,
        temperature_min: 68.0
      )
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
        daily_forecasts: [ DailyForecast.new(date: "2026-06-19") ],
        retrieved_at: Time.zone.local(2026, 6, 19, 12, 0)
      )

      cached_forecast = forecast.with_cache_status(true)

      expect(cached_forecast).to have_attributes(
        latitude: -22.96,
        longitude: -43.38,
        timezone: "America/Sao_Paulo",
        unit: "celsius",
        current_temperature: 24.8,
        from_cache: true,
        retrieved_at: Time.zone.local(2026, 6, 19, 12, 0)
      )
      expect(cached_forecast.daily_forecasts).to eq(forecast.daily_forecasts)
    end
  end

  describe "#cache_age_in_minutes" do
    it "returns the age of a cached forecast rounded down to minutes" do
      travel_to Time.zone.local(2026, 6, 19, 12, 15, 45) do
        forecast = described_class.new(
          unit: "celsius",
          from_cache: true,
          retrieved_at: Time.zone.local(2026, 6, 19, 12, 3, 30)
        )

        expect(forecast.cache_age_in_minutes).to eq(12)
      end
    end

    it "does not report an age for fresh forecasts" do
      forecast = described_class.new(unit: "celsius", from_cache: false)

      expect(forecast.cache_age_in_minutes).to be_nil
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
