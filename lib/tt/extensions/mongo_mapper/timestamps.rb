# This is in MongoMapper, but as of 0.8.2 updated_at is always overwritten.
# Also, Time.zone.now is not used if it's present.
module MongoMapper
  module Plugins
    module Timestamps
      def update_timestamps
        now = Time.zone.now #Time.now.utc
        self[:created_at] = now if !created_at_changed? && (new? && !created_at?)
        self[:updated_at] = now unless updated_at_changed? || (new? && updated_at?)
      end
    end
  end
end
