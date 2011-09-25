#!/usr/local/bin/ruby -rubygems

require 'hpricot'
require 'open-uri'
require 'pony'

BASE_URL = 'http://news.ycombinator.com/'

class Headline
  def initialize(headline, headline_url, points, 
                 comments, comments_url, time, time_units)
    @headline = headline
    @headline_url = headline_url
    @points = points
    @comments = comments
    @comments_url = comments_url
    @time = time
    @time_units = time_units
  end
  
  def to_s
    "\"#{@headline}\" [#{@headline_url}] - #{@time} #{@time_units} ago | " <<
      "#{@points} points\n#{@comments} comments " << 
      "[#{BASE_URL + @comments_url}]\n\n" 
  end
    
  attr_reader :headline
  attr_reader :headline_url
  attr_reader :points
  attr_reader :comments
  attr_reader :comments_url
  attr_reader :time
  attr_reader :time_units
end

begin
  THRESHOLD = Integer ARGV[0]
rescue ArgumentError
  puts "Proper usage: $ ./hntoem.rb [points threshold]"
  puts "Points threshold value must be an integer"
  exit
end

html = ''
open(BASE_URL).each { |f| html << f }
doc = Hpricot(html)

articles = doc/'td.title'/'a'
articles.slice! articles.length - 1

meta = doc/'td.subtext'

headlines = []
(articles.zip meta).each do |k, v|
  points = Integer v.at('span').to_plain_text.match(/\d+/).to_s
  if points > THRESHOLD
      headline = k.html
      headline_url = k.get_attribute 'href'
      data = v.at('a').following
      comments = Integer data[1].to_plain_text.match(/\d+/).to_s
      comments_url = data[1].get_attribute 'href'
      time_ago = data[0].to_plain_text.match(/ (.+) ago/).captures[0].split ' '

      headlines << Headline.new(headline, headline_url, points, comments,
                                comments_url, time_ago[0], time_ago[1])
  end
end

email = ''
password = ''
File.open(File.join(File.dirname(__FILE__), 'credentials.txt'), 'r') do |f|  
  while line = f.gets  
    if !/^email/.match(line).nil?
      email = line.split(':')[1].strip 
    elsif !/^password/.match(line).nil?
      password = line.split(':')[1].strip
    end 
  end  
end

Pony.mail(:to => email, :via => :smtp, :via_options => {
    :address => 'smtp.gmail.com',
    :port => '587',
    :enable_starttls_auto => true,
    :user_name => email,
    :password => password,
    :authentication => :plain,
},
:subject => 'HN to EM', :body => headlines) 
  

