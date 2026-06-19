class LocationResult
  ATTRIBUTES = %i[
    id
    name
    latitude
    longitude
    country
    country_code
    admin1
    admin2
    timezone
    population
    postcodes
  ].freeze

  attr_reader(*ATTRIBUTES)

  def self.from_api(attributes)
    new(
      id: attributes["id"],
      name: attributes["name"],
      latitude: attributes["latitude"],
      longitude: attributes["longitude"],
      country: attributes["country"],
      country_code: attributes["country_code"],
      admin1: attributes["admin1"],
      admin2: attributes["admin2"],
      timezone: attributes["timezone"],
      population: attributes["population"],
      postcodes: attributes["postcodes"] || []
    )
  end

  def initialize(attributes = {})
    ATTRIBUTES.each do |attribute|
      instance_variable_set("@#{attribute}", attributes[attribute])
    end
  end

  def display_name
    [ name, admin2, admin1, country ].compact_blank.uniq.join(", ")
  end
end
