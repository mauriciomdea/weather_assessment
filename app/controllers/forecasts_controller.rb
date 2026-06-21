class ForecastsController < ApplicationController
  def show
    @unit = ForecastResult.normalize_unit(params[:unit].presence || "fahrenheit")
    @location = selected_location
    @forecast = OpenMeteo::ForecastLookup.new.call(location: @location, unit: @unit)
  rescue ArgumentError, TypeError
    @forecast_error = "Please select a valid location and temperature unit."
  rescue OpenMeteo::Error
    @forecast_error = "We could not retrieve the forecast right now. Please try again."
  end

  private

  def selected_location
    attributes = location_params

    LocationResult.new(
      id: attributes[:id].presence,
      name: attributes[:name],
      latitude: Float(attributes[:latitude]),
      longitude: Float(attributes[:longitude]),
      country: attributes[:country],
      country_code: attributes[:country_code],
      admin1: attributes[:admin1],
      admin2: attributes[:admin2],
      timezone: attributes[:timezone]
    )
  end

  def location_params
    params.fetch(:location, ActionController::Parameters.new).permit(
      :id,
      :name,
      :latitude,
      :longitude,
      :country,
      :country_code,
      :admin1,
      :admin2,
      :timezone
    )
  end
end
