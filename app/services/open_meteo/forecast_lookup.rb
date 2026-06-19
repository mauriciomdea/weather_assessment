module OpenMeteo
  class ForecastLookup
    CACHE_EXPIRATION = 30.minutes

    def initialize(forecast_client: ForecastClient.new, cache_store: Rails.cache)
      @forecast_client = forecast_client
      @cache_store = cache_store
    end

    def call(location:, unit:)
      normalized_unit = ForecastResult.normalize_unit(unit)
      key = cache_key(location:, unit: normalized_unit)
      cached_forecast = cache_store.read(key)

      return cached_forecast.with_cache_status(true) if cached_forecast

      fresh_forecast = forecast_client.fetch(
        latitude: location.latitude,
        longitude: location.longitude,
        unit: normalized_unit
      ).with_cache_status(false)

      cache_store.write(key, fresh_forecast, expires_in: CACHE_EXPIRATION)
      fresh_forecast
    end

    def cache_key(location:, unit:)
      normalized_unit = ForecastResult.normalize_unit(unit)

      if location.id.present?
        "forecast/location/#{location.id}/#{normalized_unit}"
      else
        "forecast/coordinates/#{location.latitude},#{location.longitude}/#{normalized_unit}"
      end
    end

    private

    attr_reader :forecast_client, :cache_store
  end
end
