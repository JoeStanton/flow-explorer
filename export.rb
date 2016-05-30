require 'aws-sdk'
require 'pry'
$log_client = Aws::CloudWatchLogs::Client.new(region: 'eu-west-1')

groups = $log_client.describe_log_groups

def get_logs(group_name, token = nil)
	streams = $log_client.describe_log_streams(log_group_name: group_name).log_streams
	streams.reduce({}) do |h, stream|
		h[stream.log_stream_name] = get_stream(group_name, stream.log_stream_name)
		h
	end
end

def get_stream(group_name, stream_name, token = nil)
	puts group_name, stream_name, token
	response = $log_client.get_log_events({
	  log_group_name: group_name,
	  log_stream_name: stream_name,
	  next_token: token,
	  start_from_head: true
	})
        if response.next_forward_token != nil && token != response.next_forward_token
puts response.events.count
	  response.events.concat(get_stream(group_name, stream_name, response.next_forward_token))
	else
puts response.events.count
	  response.events
	end
end

logs = get_logs(ARGV[0])
logs.keys.each { |k| File.write(k, logs[k].map { |l| l.message }.join("\n") ) }
