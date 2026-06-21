module OpenMeteo
  class ForecastLookup
    CACHE_EXPIRATION = 30.minutes
    FETCH_UNIT = "fahrenheit"

    def initialize(forecast_client: ForecastClient.new, cache_store: Rails.cache, logger: Rails.logger)
      @forecast_client = forecast_client
      @cache_store = cache_store
      @logger = logger
    end

    def call(location:, unit: FETCH_UNIT)
      display_unit = ForecastResult.normalize_unit(unit)
      key = cache_key(location:)
      cached_forecast = cache_store.read(key)

      return cached_forecast.with_cache_status(true).with_unit(display_unit) if cached_forecast

      fresh_forecast = forecast_client.fetch(
        latitude: location.latitude,
        longitude: location.longitude,
        unit: FETCH_UNIT
      ).with_cache_status(false)

      cache_store.write(key, fresh_forecast, expires_in: CACHE_EXPIRATION)
      fresh_forecast.with_unit(display_unit)
    rescue OpenMeteo::Error => error
      log_failure(location:, display_unit:, error:)
      raise
    end

    def cache_key(location:)
      if location.id.present?
        "forecast/location/#{location.id}"
      else
        "forecast/coordinates/#{location.latitude},#{location.longitude}"
      end
    end

    private

    attr_reader :forecast_client, :cache_store, :logger

    def log_failure(location:, display_unit:, error:)
      logger.warn(
        "Open-Meteo forecast lookup failed " \
        "provider=open_meteo action=forecast " \
        "location=#{loggable_location(location)} fetch_unit=#{FETCH_UNIT} display_unit=#{display_unit} " \
        "error_class=#{error.class} status=#{error.status || 'unavailable'}"
      )
    end

    def loggable_location(location)
      return "id:#{location.id}" if location.id.present?

      "coordinates:#{location.latitude},#{location.longitude}"
    end
  end
end
