require 'netaddr'
require 'ruby-graphviz'
# version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status

services = File.read("/etc/services").lines.select { |l| l[0] != "#" }.reduce({}) do |h, l|
  _, pre_port, pre_description = l.split(" ")
  port = pre_port.split("/")[0].to_i
  puts port
  description = pre_description.gsub("# ", "")
  h[port] = description if port && description
  h
end

logs = File.read(ARGV[0])
internal = NetAddr::CIDR.create("172.16.0.0/16")

parsed = logs.lines
             .map { |l| l.split(" ") }
             .select { |l| l[3] != "-" && internal.contains?(l[3]) && l[4] != "-" && internal.contains?(l[4]) }
             .select { |l| services[l[6].to_i] }
             .select { |l| l[12] == "ACCEPT" }

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
puts JSON.pretty_generate(edges)

puts "Nodes: #{nodes.count}, Edges: #{edges.count}"
exit 1 if nodes.count < 1 || nodes.count > 300 || edges.count > 500

g.add_nodes(nodes)
edges.map { |e| g.add_edges(e[0], e[1], label: e[2]) }

# Generate output image
g.output(:pdf => "#{ARGV[0]}.pdf")
