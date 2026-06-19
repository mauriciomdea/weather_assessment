module OpenMeteo
  class ForecastClient
    CURRENT_VARIABLES = %w[temperature_2m weather_code].freeze
    DAILY_VARIABLES = %w[temperature_2m_max temperature_2m_min weather_code].freeze
    DEFAULT_FORECAST_DAYS = 7
    DEFAULT_TIMEZONE = "auto"

    def initialize(client: Client.new)
      @client = client
    end

    def fetch(latitude:, longitude:, unit:, forecast_days: DEFAULT_FORECAST_DAYS)
      normalized_unit = ForecastResult.normalize_unit(unit)
      response = client.get(
        "/v1/forecast",
        params: {
          latitude:,
          longitude:,
          current: CURRENT_VARIABLES.join(","),
          daily: DAILY_VARIABLES.join(","),
          temperature_unit: normalized_unit,
          timezone: DEFAULT_TIMEZONE,
          forecast_days:
        },
        action: "forecast"
      )

      ForecastResult.from_api(response, unit: normalized_unit)
    end

    private

    attr_reader :client
  end
end
