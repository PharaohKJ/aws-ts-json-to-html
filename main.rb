# coding: utf-8
require "json"
require "bigdecimal"

file = File.read(ARGV[0] || 'asrOutput-25.json')
h = JSON.parse(file)

# binding.irb

# puts h['results']['transcripts']

# puts '<!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8"><title>HTML5サンプル</title></head><body>'
#

class Record
  attr_reader :start_time, :end_time, :raw_record

  def initialize(record)
    start_time = record['start_time']
    end_time   = record['end_time']
    @start_time = BigDecimal(start_time) unless start_time.nil?
    @end_time   = BigDecimal(end_time) unless end_time.nil?
    @raw_record = record
  end

  def complement?
    start_time.nil?
  end
end

class D
  attr_reader :current_record, :next_record

  def initialize(current_record, next_record)
    @current_record = current_record
    @next_record = next_record
  end

  def next_time
    return 0 if @current_record.complement? || @next_record.complement?
    @next_record.start_time - @current_record.end_time
  end

  def continue_word?
    # next_time.to_f <= 0.7
    next_time.to_f <= 1.0
  end
end

def seconds_to_time(seconds)
  mins = seconds.to_i / 60
  hours = mins / 60
  sec = seconds - (mins * 60)
  [
    "#{hours.to_s.rjust(2, '0')}",
    "#{(mins%60).to_s.rjust(2, '0')}",
    "#{sec.to_f.to_s.rjust(5, '0')}"
  ].join(':')
end

records = h['results']['items'].map do |r|
  Record.new(r)
end

diff_records = records.each_cons(2).to_a.map { |r1, r2| D.new(r1, r2) }

puts '<!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8"><title>parse-ts-json</title></head><body>'

texts = ["#{seconds_to_time(0)} || "]

texts = diff_records.each_with_object(texts) do |r, o|
  r.current_record.raw_record['alternatives'].map do |r2|
    color = 0xff - (0xff * r2['confidence'].to_f).to_i
    o << %(<span style="color:##{color.to_i.to_s(16).rjust(2, '0')}0000;" title="#{r2['confidence'].to_f}">)
    o << r2['content']
    o << %(</span>)
  end
  o << "<hr/><br> #{seconds_to_time(r.next_record.start_time)} || " unless r.continue_word?
end

puts texts.join

puts '</body>'
