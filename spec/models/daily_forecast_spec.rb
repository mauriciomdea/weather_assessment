require "rails_helper"

RSpec.describe DailyForecast do
  it "stores daily high, low, and weather code values" do
    forecast = described_class.new(
      date: "2026-06-19",
      temperature_max: 28.4,
      temperature_min: 19.7,
      weather_code: 3
    )

    expect(forecast).to have_attributes(
      date: "2026-06-19",
      temperature_max: 28.4,
      temperature_min: 19.7,
      weather_code: 3
    )
  end
end
