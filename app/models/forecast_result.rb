class ForecastResult
  SUPPORTED_UNITS = %w[celsius fahrenheit].freeze

  attr_reader :latitude,
              :longitude,
              :timezone,
              :unit,
              :current_temperature,
              :current_weather_code,
              :current_time,
              :daily_forecasts,
              :from_cache,
              :retrieved_at

  def self.from_api(response, unit:)
    daily = response.fetch("daily", {})

    new(
      latitude: response["latitude"],
      longitude: response["longitude"],
      timezone: response["timezone"],
      unit:,
      current_temperature: response.dig("current", "temperature_2m"),
      current_weather_code: response.dig("current", "weather_code"),
      current_time: response.dig("current", "time"),
      daily_forecasts: build_daily_forecasts(daily)
    )
  end

  def self.build_daily_forecasts(daily)
    dates = daily.fetch("time", [])
    maximums = daily.fetch("temperature_2m_max", [])
    minimums = daily.fetch("temperature_2m_min", [])
    weather_codes = daily.fetch("weather_code", [])

    dates.each_with_index.map do |date, index|
      DailyForecast.new(
        date:,
        temperature_max: maximums[index],
        temperature_min: minimums[index],
        weather_code: weather_codes[index]
      )
    end
  end

  def self.normalize_unit(unit)
    normalized_unit = unit.to_s.strip.downcase
    return normalized_unit if SUPPORTED_UNITS.include?(normalized_unit)

    raise ArgumentError, "Unsupported temperature unit: #{unit.inspect}"
  end

  def initialize(attributes = {})
    @latitude = attributes[:latitude]
    @longitude = attributes[:longitude]
    @timezone = attributes[:timezone]
    @unit = self.class.normalize_unit(attributes[:unit])
    @current_temperature = attributes[:current_temperature]
    @current_weather_code = attributes[:current_weather_code]
    @current_time = attributes[:current_time]
    @daily_forecasts = attributes[:daily_forecasts] || []
    @from_cache = attributes.fetch(:from_cache, false)
    @retrieved_at = attributes[:retrieved_at] || Time.current
  end

  def temperature_unit_symbol
    unit == "fahrenheit" ? "F" : "C"
  end

  def cache_age_in_minutes
    return unless from_cache && retrieved_at

    [ (Time.current - retrieved_at) / 60, 0 ].max.floor
  end

  def with_unit(requested_unit)
    normalized_unit = self.class.normalize_unit(requested_unit)
    return self if normalized_unit == unit

    self.class.new(
      latitude:,
      longitude:,
      timezone:,
      unit: normalized_unit,
      current_temperature: convert_temperature(current_temperature, to: normalized_unit),
      current_weather_code:,
      current_time:,
      daily_forecasts: daily_forecasts.map { |daily_forecast| convert_daily_forecast(daily_forecast, to: normalized_unit) },
      from_cache:,
      retrieved_at:
    )
  end

  def with_cache_status(from_cache)
    self.class.new(
      latitude:,
      longitude:,
      timezone:,
      unit:,
      current_temperature:,
      current_weather_code:,
      current_time:,
      daily_forecasts:,
      from_cache:,
      retrieved_at:
    )
  end

  private

  def convert_daily_forecast(daily_forecast, to:)
    DailyForecast.new(
      date: daily_forecast.date,
      temperature_max: convert_temperature(daily_forecast.temperature_max, to:),
      temperature_min: convert_temperature(daily_forecast.temperature_min, to:),
      weather_code: daily_forecast.weather_code
    )
  end

  def convert_temperature(temperature, to:)
    return if temperature.nil?

    temperature = temperature.to_f

    if unit == "fahrenheit" && to == "celsius"
      (temperature - 32) * 5 / 9.0
    elsif unit == "celsius" && to == "fahrenheit"
      (temperature * 9 / 5.0) + 32
    else
      temperature
    end
  end
end
