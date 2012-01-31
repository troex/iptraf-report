#!/usr/bin/env ruby
#
# Generate simple text reports from iptraf logs
# Author: Troex Nevelin <troex@fury.scancode.ru>

log = ARGV.first
me = '81.211.22.2'

# do not edit below
i = 0
traffic = {
  'in' => {},
  'out' => {},
  'ports' => {},
  'total-in' => 0,
  'total out' => 0
}

GIGA_SIZE = 1073741824.0
MEGA_SIZE = 1048576.0
KILO_SIZE = 1024.0
def human_size(size)
  size = size.to_i
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

def show_ports(ports)
  if ports.count < 10
    ret = ports.to_s
  else
    ports.sort!
    ret = '[%d-%d] (%d)' % [ports.first, ports.last, ports.count]
  end
  ret
end

File.open(log, 'r') do |file|
  while (line = file.gets)
    i += 1
    date, protocol, interface, traf, direction, state, info = line.chomp.split(';').map { |x| x.strip }

    next if direction.nil?

    bytes = traf.match(/\d+/).to_a.first.to_i
    m, from, from_port, to, to_port = direction.match(/from (.*)\:(\d+) to (.*)\:(\d+)/).to_a

    case protocol

    when 'TCP'
      next if state != 'FIN sent'
      m, packets, bytes, rate = info.match(/(\d+) packets, (\d+) bytes, avg flow rate ([\d\.]+) /).to_a
      #p '%s -> %s = %d' % [from, to, bytes]

    when 'UDP'
      # nothing to do

    when 'ICMP'
      m, from, to = direction.match(/from (.*) to (.*)/).to_a

    else
      next

    end # case

    port = (from_port.to_i < to_port.to_i ? from_port.to_i : to_port.to_i)
    key = '%15s -> %-15s' % [from, to]
    direction = (to == me) ? 'in' : 'out'

    traffic[direction][key] ||= 0
    traffic[direction][key] += bytes.to_i
    traffic['total-' + direction] += bytes.to_i
    traffic['ports'][key] ||= []
    traffic['ports'][key].push(port) if port > 0 and !traffic['ports'][key].include?(port)

    #puts "#{i}: #{line}"
  end
end

['in', 'out'].each do |direction|
  puts direction # decor
  traffic[direction].sort_by { |k, v| v }.reverse.each do |key, bytes|
    break if bytes < 10000 # skip if less
    puts '%s = %8s  %s' % [key, human_size(bytes), show_ports(traffic['ports'][key])]
  end
  puts "Total %3s: %12s\n\n" % [direction, human_size(traffic['total-' + direction])]
end
