require 'netaddr'
require 'ruby-graphviz'
# version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status

logs = File.read(ARGV[0])
internal = NetAddr::CIDR.create("172.16.0.0/16")

require 'aws-sdk'
ec2 = Aws::EC2::Client.new(region: 'eu-west-1')
$mapping = ec2.describe_network_interfaces.network_interfaces.reduce({}) do |h, i|
  h[i.private_ip_address] = i.description
  h
end
File.write("mapping.json", JSON.pretty_generate($mapping))

all = {}

def lookup(l)
  from = $mapping[l[3]]
  to = $mapping[l[4]]
  l[3] = $mapping[l[3]] if from && from.length > 0
  l[4] = $mapping[l[4]] if to && to.length > 0
  l
end

def conn_to_s(l)
  l = lookup(l)
  from = "#{l[3]}:#{l[5]}"
  to = "#{l[4]}:#{l[6]}"
  "#{from}->#{to}@#{l[10]}-#{l[11]}"
end

def rev_conn_to_s(l)
  l = lookup(l)
  from = "#{l[4]}:#{l[6]}"
  to = "#{l[3]}:#{l[5]}"
  "#{from}->#{to}"
end

returning = {}

parsed = logs.lines
             .map { |l| l.split(" ") }
             .select { |l| l[3] != "-" && internal.contains?(l[3]) && l[4] != "-" && internal.contains?(l[4]) }
             .select { |l| l[12] == "ACCEPT" }
            #  .select { |l| !returning[conn_to_s(l)] && returning[rev_conn_to_s(l)] = true }

puts parsed.map {|p| conn_to_s(p) }.join("\n")

from = parsed.map { |l| l[3] }.uniq
to = parsed.map { |l| l[4] }.uniq
nodes = from.concat(to)

g = GraphViz.new(:G, :type => :digraph)

edges = parsed.map do |l|
  from = l[3]
  to = l[4]
  dest_port = l[6].to_i
  [from, to, dest_port]
end.uniq

require 'json'
report = all.values.reduce({}) { |h, v| h[v] ||= 0; h[v] += 1; h }
puts report

puts "PARSED"
puts edges.count

puts "Nodes: #{nodes.count}, Edges: #{edges.count}"
exit 1 if nodes.count < 1 || nodes.count > 300 || edges.count > 500

g.add_nodes(nodes)
edges.map { |e| g.add_edges(e[0], e[1], label: e[2]) }

# Generate output image
g.output(:pdf => "#{ARGV[0]}.pdf")
