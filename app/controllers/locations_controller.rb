class LocationsController < ApplicationController
  def index
    @query = params[:query].to_s
    @unit = normalize_unit(params[:unit])
    @locations = []
    @search_performed = search_query?

    return unless @search_performed

    @locations = OpenMeteo::LocationSearch.new.call(@query)
  rescue OpenMeteo::Error
    @locations = []
    @search_performed = true
    @location_search_error = "We could not retrieve matching locations right now. Please try again."
  end

  private

  def search_query?
    @query.strip.length >= 2
  end

  def normalize_unit(unit)
    ForecastResult.normalize_unit(unit.presence || "celsius")
  rescue ArgumentError
    "celsius"
  end
end
