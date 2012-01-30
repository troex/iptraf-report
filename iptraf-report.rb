#!/usr/bin/env ruby1.9.1

log = ARGV.first
gw = '81.211.22.2'

i = 0
input = {}
output = {}
total = { 'in' => 0, 'out' => 0 }
ports = {}

def show_ports(ports)
  if ports.count < 10
    ret = ports.to_s
  else
    ports.sort!
    ret = '[%d-%d] (%d)' % [ports.first, ports.last, ports.count]
  end
  ret
end

GIGA_SIZE = 1073741824.0
MEGA_SIZE = 1048576.0
KILO_SIZE = 1024.0
def human_size(size)
  case
    when size < KILO_SIZE
      "%d  B" % size
    when size < MEGA_SIZE
      "%d KB" % (size / KILO_SIZE)
    when size < GIGA_SIZE
      "%.1f MB" % (size / MEGA_SIZE)
    else
      "%.2f GB" % (size / GIGA_SIZE)
  end
end

File.open(log, 'r') do |file|
  while (line = file.gets)
    i += 1
    date, protocol, interface, traffic, direction, state, info = line.chomp.split(';').map { |x| x.strip }

    next if direction.nil?

    bytes = traffic.match(/\d+/).to_a.first.to_i
    m, from, from_port, to, to_port = direction.match(/from (.*)\:(\d+) to (.*)\:(\d+)/).to_a

    case protocol

    when 'TCP'
      next if state != 'FIN sent'
      m, packets, bytes, rate = info.match(/(\d+) packets, (\d+) bytes, avg flow rate ([\d\.]+) /).to_a
      #p '%s -> %s = %d' % [from, to, bytes]

    when 'UDP'
      # ok

    when 'ICMP'
      m, from, to = direction.match(/from (.*) to (.*)/).to_a

    else
      next

    end # case

    port = (from_port.to_i < to_port.to_i ? from_port.to_i : to_port.to_i)

    k = '%15s -> %-15s' % [from, to]

    if from == gw
      from = 'gw'
      output[k] ||= 0
      output[k] += bytes.to_i
      ports[k] ||= []
      ports[k].push(port) if port > 0 and !ports[k].include?(port)
      total['out'] += bytes.to_i
    end

    if to == gw
      to = 'gw'
      input[k] ||= 0
      input[k] += bytes.to_i
      ports[k] ||= []
      ports[k].push(port) if port > 0 and !ports[k].include?(port)
      total['in'] += bytes.to_i
    end
    #puts "#{i}: #{line}"
  end
end

puts "=== OUT ==="
output.sort_by { |k, v| v }.reverse.each do |k, v|
  break if v < 10000
  puts '%s = %8s  %s' % [k, human_size(v), show_ports(ports[k])]
end
puts "Total OUT: %12d\n\n" % total['out']

puts "=== IN ==="
input.sort_by { |k, v| v }.reverse.each do |k, v|
  break if v < 10000
  puts '%s = %8s  %s' % [k, human_size(v), show_ports(ports[k])]
end
puts "Total IN:  %12d\n\n" % total['in']
