# coding: utf-8
require "json"
require "bigdecimal"

file = File.read(ARGV[0] || 'asrOutput-25.json')
h = JSON.parse(file)

class Record
  attr_reader :start_time, :end_time, :raw_record, :speaker

  def initialize(record)
    start_time = record['start_time']
    end_time   = record['end_time']
    @start_time = BigDecimal(start_time) unless start_time.nil?
    @end_time   = BigDecimal(end_time) unless end_time.nil?
    @raw_record = record
    @speaker = record['speaker_label']
  end

  def complement?
    start_time.nil?
  end
end

class RecordPair
  # RecordとRecordの関係性を簡単にするヘルパ的クラス
  attr_reader :current_record, :next_record

  def initialize(current_record, next_record)
    @current_record = current_record
    @next_record = next_record
  end

  # 今のrecordと次のrecordの時差
  def next_time
    return 0 if @current_record.complement? || @next_record.complement?
    @next_record.start_time - @current_record.end_time
  end

  # 次のrecordとつながった言葉とみなすかどうか
  # 時差を確認するが、話者が替わった場合は続かないとみなす
  def continue_word?
    # next_time.to_f <= 0.7
    return false if @current_record.speaker != @next_record.speaker
    next_time.to_f <= continue_word_duration
  end

  def continue_word_duration
    5.0
  end

  def continue_word_duration_same_speaker
    10.0
  end
end

def seconds_to_time(seconds)
  mins = seconds.to_i / 60
  hours = mins / 60
  sec = seconds - (mins * 60)
  [
    hours.to_s.rjust(2, '0').to_s,
    (mins % 60).to_s.rjust(2, '0'),
    sec.to_f.to_s.rjust(5, '0')
  ].join(':')
end

records = h['results']['items'].map do |r|
  Record.new(r)
end

speakers = records.map(&:speaker).uniq

diff_records = records.each_cons(2).to_a.map { |r1, r2| RecordPair.new(r1, r2) }

puts '<!DOCTYPE html><html lang="ja"><head><meta charset="UTF-8"><title>parse-ts-json</title></head><body>'

puts '<h1>話者</h1>'
puts speakers.join(', ')
puts '<br/>'
puts speakers.count
puts '<hr>'

texts = ["#{seconds_to_time(0)} || "]

texts = diff_records.each_with_object(texts) do |r, o|
  sec = r.current_record.raw_record['start_time'].to_f
  t_s = format('%<h>02d:%<m>02d:%<s>02d', h: sec / 3600, m: sec / 60 % 60, s: sec % 60)
  r.current_record.raw_record['alternatives'].map do |r2|
    color = 0xff - (0xff * r2['confidence'].to_f).to_i
    score = format('%#<s>3.2f', s: (r2['confidence'].to_f * 100.0).round(2))
    title = "#{t_s} | #{score} / 100.00"
    o << %(<span style="color:##{color.to_i.to_s(16).rjust(2, '0')}0000;" title="#{title}">)
    o << r2['content']
    o << %(</span>)
    o << "<br>" if r2['content'].include?('。')
  end
  o << "<hr/><br> #{seconds_to_time(r.next_record.start_time)} | #{r.next_record.speaker} | " unless r.continue_word?
end

puts texts.join

puts '</body>'
