#!/usr/bin/env ruby
# coding: utf-8
# See LICENSE.txt for licensing information.

# I assume I've used this to get the contents of what is now lib/data.rb.
# Data-driven assembly ftw!
#
# Honestly, I leave it as close to as it were two years ago as I can.
# Perlish stuff.

%w{ pp open-uri nokogiri }.each{|g| require g}

MODES = %w{ n d z zx zy zxr zyr a ax ay ar r e }

puts "MODES = [ #{MODES.collect{|m| ":#{m}"}.join(', ')} ]\n"

opcodes = Hash.new
page = Nokogiri::HTML.parse(open('http://sta.c64.org/cbm64mcinst2.html'))
page.xpath('//tr').each do |row|
  data = row.xpath('td').collect{|c| c.content}
  next unless data.length == 14
  inst = data.shift.downcase.to_sym
  opcodes[inst] = Hash.new
  data.each_with_index do |code, i|
    next if code[0] != '$'
    mode = MODES[i].to_sym
    op = code.gsub(/\$/, '').to_i(16)
    opcodes[inst][mode] = Hash.new
    opcodes[inst][mode][:byte] = op
  end
end

page = Nokogiri::HTML.parse(open('http://sta.c64.org/cbm64mctime.html'))
page.xpath('//tr').each do |row|
  data = row.xpath('td').collect{|c| c.content}
  next unless data.length == 14
  inst = data.shift.downcase.to_sym
  data.each_with_index do |code, i|
    next unless m = code.match(/(\d)(\+)?(\*)?/)
    cycles = m[1].to_i
    boundary = m[2] ? true : false
    branch = m[3] ? true : false
    mode = MODES[i].to_sym
    #puts "#{inst} #{mode} #{cycles} #{boundary} #{branch}"
    opcodes[inst][mode] ||= Hash.new
    opcodes[inst][mode][:cycles] = cycles
    opcodes[inst][mode][:page] = true if boundary
    opcodes[inst][mode][:branch] = true if branch
  end
end

puts 'OPCODES = '
pp(opcodes, width = 120)

petscii = Hash.new
page = Nokogiri::HTML.parse(open('http://www.andrijar.com/tables/petsci.htm'))
page.xpath('//tr').each do |row|
  data = row.xpath('td').collect{|c| c.content}
  0.step(11, 3).each do |i|
    byte = data[i].to_i
    symbol = data[i+2]
    next if (symbol == 'NOC' or symbol == '')
    point = symbol.unpack('U*').first
    petscii[point] = byte
  end
end

puts 'PETSCII = '
pp(petscii, width = 120)

# for basic tokens
#tokens = {}
#STDIN.each_line do |l|
#  code, *rest = l.split(' ')
#  byte = code.split('/').first
#  name = rest.first.split(' ').first
#  tokens[name] = byte.to_i
#end
#
#pp(tokens, width=120)
