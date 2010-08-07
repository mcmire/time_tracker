module TimeTracker
  module Extensions
    module MongoMapper
      module PrettyPrint
        def pretty_print(q)
          #attrs = self.class.column_names.inject([]) {|arr, name|
          #  if has_attribute?(name) || new_record?
          #    arr << [name, read_attribute(name)]
          #  end
          #  arr
          #}
          #our_attributes = self.attributes
          #attrs = self.keys.map {|key| [key.name, our_attributes[key.name]] }
          q.group(0, "#<#{self.class}", "}>") {
            q.breakable " "
            q.group(1) {
              q.seplist(self.attributes) {|pair|
                q.pp pair[0]
                q.text ": "
                q.pp pair[1]
              }
            }
          }
        end
      end
    end
  end
end

MongoMapper::Document.module_eval {
  include TimeTracker::Extensions::MongoMapper::PrettyPrint
}
MongoMapper::EmbeddedDocument.module_eval {
  include TimeTracker::Extensions::MongoMapper::PrettyPrint
}