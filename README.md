# Weather Assessment

Weather Assessment is a Ruby on Rails application for searching global
locations and retrieving weather forecasts. The application is being built in
small, reviewed steps with RSpec examples serving as executable documentation
and acceptance criteria.

## Current Status

Step 5 adds cached forecast lookup. Forecasts are now cached for 30 minutes by
selected location and temperature unit, and forecast results include a
`from_cache` flag that the user interface can display in later steps.

## Requirements

- Ruby 3.4.9
- Rails 7.2.3.1
- SQLite 3
- Bundler

The project is intentionally configured for a local Ruby/Rails setup rather
than Docker. This keeps the assessment lightweight while still documenting the
exact versions required to run it.

## Setup

Install the required Ruby version, then install dependencies:

```bash
bundle install
```

Prepare the local database:

```bash
bin/rails db:prepare
```

Run the application:

```bash
bin/rails server
```

Run the test suite:

```bash
bundle exec rspec
```

## Implementation Plan

The application will be built through separate commits:

1. Initialize Rails, RSpec, and project documentation.
2. Add an Open-Meteo API client foundation.
3. Add global location search.
4. Add forecast retrieval with Celsius/Fahrenheit unit preference.
5. Add cached forecast lookup with a 30-minute expiration.
6. Add progressive location search with Hotwire/Turbo/Stimulus.
7. Add the user-facing forecast display.
8. Add API failure logging and friendly error states.
9. Polish the final documentation and acceptance notes.

## Approach

The original assessment asks for forecast lookup from an address or ZIP code.
This implementation will generalize that requirement by accepting a free-form
global location search. Users will select a matching location, and the selected
location's coordinates will be used to retrieve weather data from Open-Meteo.

This keeps ZIP and postal-code searches possible while also supporting broader
international place names such as "Jacarepagua".

## API Client Foundation

The project uses Ruby's standard `Net::HTTP` library for Open-Meteo requests.
That keeps the dependency footprint small while still giving enough control over
timeouts, HTTPS, query parameters, and error handling.

The shared `OpenMeteo::Client` is responsible for:

- Building API request URLs.
- Applying open and read timeouts.
- Parsing successful JSON responses.
- Raising clear custom errors for request, response, and JSON parsing failures.
- Logging sanitized failure details through `Rails.logger.warn`.

Specs use WebMock so API behavior can be described without relying on live
network calls.

## Global Location Search

`OpenMeteo::LocationSearch` uses the Open-Meteo Geocoding API to search global
place names and postal codes. Blank or one-character searches return an empty
list without making an external request, matching Open-Meteo's documented
behavior for short search terms.

Results are normalized into `LocationResult` objects so the rest of the
application can work with a clear internal shape instead of raw API hashes.
Each result exposes coordinates, country, administrative area, timezone, and a
human-readable display name such as:

```text
Jacarepaguá, Rio de Janeiro, Brazil
```

## Forecast Retrieval

`OpenMeteo::ForecastClient` retrieves weather data from the Open-Meteo Forecast
API using the selected location's latitude and longitude. It requests:

- Current temperature.
- Current weather code.
- Daily maximum temperature.
- Daily minimum temperature.
- Daily weather code.

The client supports both `celsius` and `fahrenheit` through Open-Meteo's
`temperature_unit` parameter. Unsupported units are rejected before making an
external API request so invalid user input fails fast and predictably.

Forecast responses are normalized into `ForecastResult` and `DailyForecast`
objects. This keeps downstream caching and UI code independent from the raw API
response shape.

## Caching Strategy

`OpenMeteo::ForecastLookup` coordinates forecast retrieval and caching. It uses
explicit cache reads and writes instead of `Rails.cache.fetch` so the returned
`ForecastResult` can accurately indicate whether it came from cache.

Forecasts are cached for 30 minutes. Cache keys include the selected location
and the requested temperature unit:

```text
forecast/location/3451190/celsius
forecast/location/3451190/fahrenheit
```

When an Open-Meteo location ID is unavailable, the cache falls back to
coordinates:

```text
forecast/coordinates/48.8566,2.3522/celsius
```

Including the unit in the cache key prevents serving Celsius data for a
Fahrenheit request, or the other way around.

## Testing Strategy

RSpec will be used for behavior-driven development. Specs will describe the
expected behavior before or alongside each feature and will serve as both
documentation and acceptance criteria for the implementation.
