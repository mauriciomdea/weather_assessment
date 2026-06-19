module OpenMeteo
  class LocationSearch
    GEOCODING_BASE_URL = "https://geocoding-api.open-meteo.com"
    DEFAULT_RESULT_COUNT = 10
    DEFAULT_LANGUAGE = "en"

    def initialize(client: Client.new(base_url: GEOCODING_BASE_URL))
      @client = client
    end

    def call(query, count: DEFAULT_RESULT_COUNT, language: DEFAULT_LANGUAGE)
      normalized_query = query.to_s.strip
      return [] if normalized_query.length < 2

      response = client.get(
        "/v1/search",
        params: {
          name: normalized_query,
          count:,
          language:,
          format: "json"
        },
        action: "geocoding"
      )

      Array(response["results"]).map { |result| LocationResult.from_api(result) }
    end

    private

    attr_reader :client
  end
end
