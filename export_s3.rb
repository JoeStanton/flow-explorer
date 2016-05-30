require 'aws-sdk'
client = Aws::CloudWatchLogs::Client.new(region: 'eu-west-1')

resp = client.create_export_task({
  task_name: "Flow Logs Export",
  log_group_name: ARGV[0],
  log_stream_name_prefix: "eni",
  from: Time.now.to_i - (1000 * 60 * 60 * 24 * 7),
  to: Time.now.to_i,
  destination: ARGV[0],
  destination_prefix: "flow",
})

puts resp.task_id
