# Weather Assessment

Weather Assessment is a Ruby on Rails application for searching global
locations and retrieving weather forecasts. The application is being built in
small, reviewed steps with RSpec examples serving as executable documentation
and acceptance criteria.

## Current Status

Step 1 initializes the Rails application, configures the project for RSpec, and
documents the local development setup. Forecast functionality will be added in
later steps.

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

## Testing Strategy

RSpec will be used for behavior-driven development. Specs will describe the
expected behavior before or alongside each feature and will serve as both
documentation and acceptance criteria for the implementation.
