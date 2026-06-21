class LocationsController < ApplicationController
  def index
    @query = params[:query].to_s
    @unit = normalize_unit(params[:unit])
    @locations = []
    @search_performed = @query.present?

    return unless @search_performed

    @locations = Zippopotamus::LocationSearch.new.call(@query)
  rescue Zippopotamus::Error
    @locations = []
    @search_performed = true
    @location_search_error = "We could not retrieve matching locations right now. Please try again."
  end

  private

  def normalize_unit(unit)
    ForecastResult.normalize_unit(unit.presence || "celsius")
  rescue ArgumentError
    "celsius"
  end
end
