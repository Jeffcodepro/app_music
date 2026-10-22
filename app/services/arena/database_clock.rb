module Arena
  class DatabaseClock
    def self.now
      value = ActiveRecord::Base.uncached { ActiveRecord::Base.connection.select_value("SELECT clock_timestamp()") }
      value.respond_to?(:utc) ? value : Time.parse(value.to_s)
    end
  end
end
