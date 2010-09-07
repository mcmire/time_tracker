require 'httparty'

module TimeTracker
  module Service
    class PivotalTracker
      # A lot of this below was stolen shamelessly from the pivotal-tracker gem
      # So, portions copyright Joslyn Esser
      
      # TODO: Require options
      
      include HTTParty
      format :xml
      
      STATES = {
        "unscheduled" => "unstarted",
        "unstarted"   => "unstarted",
        "started"     => "running",
        "finished"    => "finished",
        "delivered"   => "finished",
        "accepted"    => "finished",
        "rejected"    => "finished"
      }
      
      TYPES = %w(feature chore bug)
      
      attr_reader :api_key, :headers, :base_uri
      
      def initialize(options)
        options.symbolize_keys!
        @api_key = options[:api_key]
        @headers = {'X-TrackerToken' => @api_key}
        @base_uri = "http#{'s' if options[:ssl]}://www.pivotaltracker.com/services/v3"
      end
      
      def valid?
        response = get_response(:head, "/activities?limit=1")
        response.code != 401
      end
      
      def pull_tasks!(project=nil)
        if TimeTracker.config["last_pulled_times"]
          if project
            time = TimeTracker.config["last_pulled_times"][project.external_id.to_s]
          else
            time = TimeTracker.config["last_pulled_times"].values.min
          end
          formatted_date = time.strftime("#{time.month}/#{time.day}/%Y")
        end
        path = [
          ("/projects/#{project.external_id}" if project),
          "/stories",
          ("?modified_since=#{formatted_date}" if formatted_date)
        ].compact.join
        stories = request(:get, path, "stories")
        for story in stories
          p = project || TimeTracker::Project.first(:external_id => story.project_id)
          opts = { :external_id => story.id }
          task = p.tasks.first(opts) || p.tasks.build(opts)
          task.update_attributes!(
            :name => story.name,
            :state => STATES[story.current_state],
            :created_by => story.requested_by,
            :owned_by => story.owned_by,
            # Note that this overrides the following... is that bad?
            :created_at => story.created_at,
            :updated_at => story.updated_at
          )
          task.add_to_set(:tags => "t:#{story.story_type}")
          task.reload # have to do this to load the new tag into the document
        end
        last_pulled_times = TimeTracker.config["last_pulled_times"] ||= {}
        if project
          last_pulled_times[project.external_id.to_s] = Time.now.utc
        else
          external_ids = TimeTracker::Project.fields(:external_id).map(&:external_id)
          for id in external_ids
            last_pulled_times[id.to_s] = Time.now.utc
          end
        end
        TimeTracker.config.save
      end
      
      def check_task_exists!(task)
        path = "/projects/#{task.project.external_id}/stories/#{task.external_id}"
        response = get_response(:get, path)
        raise_errors(response)
        return true
      end
      
      def push_task!(task)
        path = "/projects/#{task.project.external_id}/stories/#{task.external_id}"
        response = get_response(:put, path, :body => task_to_xml(task))
        raise_errors(response)
        return true
      end
      
      def task_to_xml(task)
        <<EOT.strip
<story>
  <name>#{task.name}</name>
  <story_type>#{task_type(task)}</story_type>
  <current_state>#{task_state(task)}</current_state>
  <requested_by>#{task.created_by}</requested_by>
  <owned_by>#{task.owned_by}</owned_by>
  <labels>#{task_labels(task)}</labels>
</story>
EOT
      end
      
      def task_type(task)
        for tag in task.tags
          if tag =~ /^t:(.+)$/
            return $1
          end
        end
        return nil
      end
      
      def task_state(task)
        case task.state
          when "unstarted" then "unscheduled"
          when "running"   then "started"
          when "finished"  then (task_type(task) == "feature") ? "accepted" : "finished"
        end
      end
      
      def task_labels(task)
        task.tags.reject {|t| t =~ /^t:/ }.join(",")
      end
      
    private
      def request(method, path, resource, options={})
        response = get_response(method, path, options)
        raise_errors(response)
        parse_response(response, resource)
      end
      
      def get_response(method, path, options={})
        self.class.__send__(method, path, options.merge(:base_uri => @base_uri, :headers => @headers))
      end
      
      def raise_errors(response)
        case response.code
        when 401
          raise Service::UnauthorizedError.new(response, "(#{response.code}): #{response.message} - #{response.body if response}")
        when 404
          raise Service::ResourceNotFoundError.new(response, "(#{response.code}): #{response.message}")
        when 422
          raise Service::ResourceInvalidError.new(response, "(#{response.code}): #{response['errors'].inspect if response['errors']}")
        when 500..599
          raise Service::InternalError.new(response, "(#{response.code}): #{response.message} - #{response['message'] if response}")
        end
      end

      # Create Hashie::Mash objects from response data for the given resource(s)
      def parse_response(response, resource)
        response = cleanup_pivotal_data(response.body)
        data = response[resource]
        if data.is_a?(Array)
          data.collect {|object| Hashie::Mash.new(object)}
        else
          Hashie::Mash.new(data)
        end
      end

      # Make Crack's XML parsing happy by correctly defining Pivotal's nested collections as arrays
      # This can be removed when all collections returned by Pivotal Tracker's API have the type=array attribute set
      def cleanup_pivotal_data(body)
        %w{ projects memberships iterations stories }.each do |resource|
          body.gsub!("<#{resource}>", "<#{resource} type=\"array\">")
        end
        response = Crack::XML.parse(body)
      end
    end
  end
end