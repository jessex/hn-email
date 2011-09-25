#!/usr/local/bin/ruby -rubygems

require 'open-uri'
require 'json'
require 'pony'

class Headline
  def initialize(title, title_url, points, 
                 comments, comments_url, time, time_units)
    @title = title
    @title_url = title_url
    @points = points
    @comments = comments
    @comments_url = comments_url
    @time = time
    @time_units = time_units
  end
  
  def to_s
    "#{@title} [#{@title_url}] - #{@time} #{@time_units} ago | " <<
      "#{@points} points\n#{@comments} comments [#{@comments_url}]\n\n" 
  end
end

begin
  THRESHOLD = Integer ARGV[0]
rescue ArgumentError
  puts "Proper usage: $ ./hntoem.rb [points threshold]"
  puts "Points threshold value must be an integer"
  exit
end

json = ''
open("http://api.ihackernews.com/page").each { |f| json << f }
articles = JSON.parse(json)['items']

headlines = []
articles.each do |a|
  points = a['points']
  if points > THRESHOLD
    title = a['title']
    title_url = a['url']
    comments = a['commentCount']
    comments_url = 'http://news.ycombinator.com/item?id=%d' % a['id']
    time_ago = a['postedAgo'].match(/(.+) ago/).captures[0].split ' '
    
    headlines << Headline.new(title, title_url, points, comments,
                              comments_url, Integer(time_ago[0]), time_ago[1])
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
  

