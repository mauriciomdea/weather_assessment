# Weather Assessment

Weather Assessment is a Ruby on Rails application that lets a user search for a
global location, choose one of the matching results, and view a weather forecast
for that selected place.

The original assessment asks for address input, forecast retrieval, display of
forecast details, 30-minute caching, and an indicator when results come from
cache. This implementation satisfies those requirements and generalizes the
input model from ZIP-only lookup to global location search.

## Requirements

- Ruby 3.4.9
- Rails 7.2.3.1
- SQLite 3
- Bundler

This project intentionally uses a local Ruby/Rails setup instead of Docker. The
goal is to keep the assessment lightweight while documenting the exact versions
needed to run it.

## Setup

Install Ruby 3.4.9 and Rails 7.2.3.1, then install dependencies:

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

Open:

```text
http://127.0.0.1:3000
```

Run the test suite:

```bash
bundle exec rspec
```

Run style checks:

```bash
bundle exec rubocop
```

## User Flow

1. The user enters a free-form location query, such as `Jacarepagua`, `Berlin`,
   or `10001`.
2. The app searches global locations through the Open-Meteo Geocoding API.
3. Matching locations are displayed progressively with Turbo and Stimulus.
4. The user selects a location.
5. The user can choose Celsius or Fahrenheit.
6. The app retrieves forecast data from Open-Meteo.
7. The app displays current temperature, weather code, and daily high/low
   forecasts.
8. Forecasts are cached for 30 minutes by selected location and unit.
9. Cached forecast pages show how many minutes ago the forecast was last
   updated.

## Requirement Mapping

- Accept an address as input: the app accepts free-form global location input.
- Retrieve forecast data: selected locations are resolved to latitude/longitude
  and passed to Open-Meteo Forecast.
- Include current temperature: shown on the forecast page.
- Bonus high/low or extended forecast: daily high/low forecast values are shown.
- Display forecast details: current and daily forecast sections are rendered.
- Cache for 30 minutes: handled by `OpenMeteo::ForecastLookup`.
- Display cache indicator: cached forecast pages show the age of the cached
  result in minutes.

## Architecture

The app keeps controllers thin and puts business behavior in small service and
value objects.

```text
app/controllers/locations_controller.rb
app/controllers/forecasts_controller.rb

app/services/open_meteo/client.rb
app/services/open_meteo/location_search.rb
app/services/open_meteo/forecast_client.rb
app/services/open_meteo/forecast_lookup.rb

app/models/location_result.rb
app/models/forecast_result.rb
app/models/daily_forecast.rb
```

`OpenMeteo::Client` owns HTTP behavior, JSON parsing, timeouts, custom errors,
and low-level API failure logging.

`OpenMeteo::LocationSearch` searches global place names and postal codes through
Open-Meteo Geocoding.

`OpenMeteo::ForecastClient` retrieves current and daily forecast data from
Open-Meteo Forecast.

`OpenMeteo::ForecastLookup` coordinates forecast retrieval and caching.

The value objects normalize API responses so controllers and views do not depend
on raw response hashes.

## API Choices

The app uses Open-Meteo because it provides both geocoding and forecast APIs,
requires no API key for this assessment/demo use case, supports global location
search, and supports Celsius/Fahrenheit forecast parameters directly.

The implementation uses Ruby's standard `Net::HTTP` instead of adding another
HTTP library. That keeps the dependency footprint small while still giving
control over HTTPS, query parameters, timeouts, and error handling.

## Caching Strategy

Forecasts are cached for 30 minutes using explicit cache reads and writes.
Explicit reads make it possible to reliably return a `from_cache` flag and show
how old a cached result is.

Development and test use Rails' in-memory cache store so this behavior works
locally without requiring `rails dev:cache`.

Example cache keys:

```text
forecast/location/3451190/celsius
forecast/location/3451190/fahrenheit
```

If a location has no Open-Meteo ID, the cache falls back to coordinates:

```text
forecast/coordinates/48.8566,2.3522/celsius
```

The unit is part of the cache key to avoid serving Celsius data for a
Fahrenheit request, or the reverse.

## Error Handling And Observability

Controllers show friendly messages when upstream calls fail:

- Location search failure: `We could not retrieve matching locations right now.
  Please try again.`
- Forecast lookup failure: `We could not retrieve the forecast right now.
  Please try again.`

The services log useful diagnostic context through `Rails.logger.warn`.

Location search logs:

- provider and action
- query length, not the raw query
- result count
- language
- error class
- upstream status when available

Forecast lookup logs:

- provider and action
- selected location ID or coordinates
- requested unit
- error class
- upstream status when available

Raw free-form address/search input is not written to logs.

## Testing Strategy

RSpec is used for behavior-driven development. Specs act as executable
documentation and acceptance criteria.

WebMock blocks external network access in specs so test results do not depend on
live API availability.

Coverage includes:

- API client success and failure behavior.
- Global location search behavior.
- Forecast response normalization.
- Celsius/Fahrenheit unit handling.
- 30-minute cache behavior and cache indicators.
- Progressive location search request behavior.
- Forecast display request behavior.
- Service-level logging for upstream failures.

## Validation

The final validation commands are:

```bash
bundle exec rspec
bundle exec rubocop
bundle exec brakeman --quiet
```

At the time of this documentation pass, the suite contains 44 passing examples.
RuboCop reports no offenses. Brakeman reports no application-code security
warnings, but it does report one weak dependency warning because Rails 7.2.3.1
support ends on August 9, 2026; this project intentionally uses Rails 7.2.3.1
to match the assessment setup.

## Assumptions

- The app supports global place names and postal codes rather than only US ZIP
  codes.
- A user must select one of the returned locations before forecast retrieval.
- Weather codes are displayed as raw Open-Meteo codes. A user-friendly weather
  code translation table would be a good enhancement.
- Rails' configured cache store is sufficient for the assessment. A production
  deployment may need a shared cache store.

## Challenges

The main implementation challenge was keeping the original ZIP-code-oriented
requirement aligned with a broader global address search experience. I chose to
document that explicitly and cache by selected location plus unit rather than by
raw query string, because raw queries can be ambiguous.

Another practical challenge was local development through WSL on a Windows
mounted directory. The app itself is standard Rails, but generated binstub file
permissions needed care during setup.

## Future Improvements

- Translate Open-Meteo weather codes into human-readable descriptions.
- Add weather icons.
- Add system specs with browser-level Turbo/Stimulus interaction coverage.
- Persist recent searches.
- Add retry/backoff for retryable upstream API failures.
- Configure a shared production cache store if deployed beyond a single process.
- Add deployment instructions.
