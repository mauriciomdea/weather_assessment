require "json"
require "net/http"

module Zippopotamus
  class Client
    BASE_URL = "https://api.zippopotam.us"
    DEFAULT_TIMEOUT = 5

    def initialize(base_url: BASE_URL, logger: Rails.logger, open_timeout: DEFAULT_TIMEOUT, read_timeout: DEFAULT_TIMEOUT)
      @base_uri = URI(base_url)
      @logger = logger
      @open_timeout = open_timeout
      @read_timeout = read_timeout
    end

    def get(path, action:)
      uri = build_uri(path)
      response = request(uri)

      unless response.is_a?(Net::HTTPSuccess)
        log_failure(action:, uri:, status: response.code)
        raise ResponseError.new("Zippopotam.us #{action} failed with HTTP #{response.code}", action:, status: response.code)
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => error
      log_failure(action:, uri:, error:)
      raise ParseError.new("Zippopotam.us #{action} returned invalid JSON", action:)
    rescue Timeout::Error, SocketError, SystemCallError, Net::OpenTimeout, Net::ReadTimeout => error
      log_failure(action:, uri:, error:)
      raise RequestError.new("Zippopotam.us #{action} request failed", action:)
    end

    private

    attr_reader :base_uri, :logger, :open_timeout, :read_timeout

    def build_uri(path)
      uri = base_uri.dup
      uri.path = File.join(base_uri.path, path)
      uri
    end

    def request(uri)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.open_timeout = open_timeout
        http.read_timeout = read_timeout
        http.get(uri.request_uri)
      end
    end

    def log_failure(action:, uri:, status: nil, error: nil)
      details = [
        "provider=zippopotamus",
        "action=#{action}",
        "path=#{uri&.path}",
        "status=#{status || 'unavailable'}"
      ]

      details << "error_class=#{error.class}" if error
      details << "message=#{error.message}" if error

      logger.warn("Zippopotam.us request failed #{details.join(' ')}")
    end
  end
end
