module OpenMeteo
  class Error < StandardError
    attr_reader :action, :status

    def initialize(message, action:, status: nil)
      super(message)
      @action = action
      @status = status
    end
  end
end
