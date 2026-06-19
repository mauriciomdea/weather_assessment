class DailyForecast
  ATTRIBUTES = %i[
    date
    temperature_max
    temperature_min
    weather_code
  ].freeze

  attr_reader(*ATTRIBUTES)

  def initialize(attributes = {})
    ATTRIBUTES.each do |attribute|
      instance_variable_set("@#{attribute}", attributes[attribute])
    end
  end
end
