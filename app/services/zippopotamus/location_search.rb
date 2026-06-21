module Zippopotamus
  class LocationSearch
    COUNTRY_CODE = "us"
    ZIP_CODE_PATTERN = /\b(\d{5})(?:-\d{4})?\b/

    def initialize(client: Client.new, logger: Rails.logger)
      @client = client
      @logger = logger
    end

    def call(query)
      zip_code = extract_zip_code(query)
      return [] unless zip_code

      response = client.get("/#{COUNTRY_CODE}/#{zip_code}", action: "zip_code_lookup")

      build_locations(response)
    rescue ResponseError => error
      return [] if error.status.to_s == "404"

      log_failure(zip_code:, error:)
      raise
    rescue Zippopotamus::Error => error
      log_failure(zip_code:, error:)
      raise
    end

    private

    attr_reader :client, :logger

    def extract_zip_code(query)
      query.to_s.match(ZIP_CODE_PATTERN)&.[](1)
    end

    def build_locations(response)
      post_code = response["post code"]
      country = response["country"]
      country_code = response["country abbreviation"]

      Array(response["places"]).each_with_index.map do |place, index|
        LocationResult.new(
          id: "#{country_code}-#{post_code}-#{index}",
          name: place["place name"],
          latitude: place["latitude"].to_f,
          longitude: place["longitude"].to_f,
          country:,
          country_code:,
          admin1: place["state"],
          postcodes: [ post_code ]
        )
      end
    end

    def log_failure(zip_code:, error:)
      logger.warn(
        "Zippopotam.us ZIP code lookup failed " \
        "provider=zippopotamus action=zip_code_lookup " \
        "zip_code_present=#{zip_code.present?} " \
        "error_class=#{error.class} status=#{error.status || 'unavailable'}"
      )
    end
  end
end
