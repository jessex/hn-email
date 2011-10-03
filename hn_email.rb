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

def to_minutes(time, time_units)
  if !/day.?/.match(time_units).nil?
    return time * 1440
  elsif !/hour.?/.match(time_units).nil?
    return time * 60
  elsif !/minute.?/.match(time_units).nil?
    return time
  else
    raise ArgumentError
  end
end

#get filters from command line arguments
filters = {}
begin
  ARGV.each_with_index do |arg, i|
    if arg == '-p' or arg == '-c'
      if ARGV[1].nil? or ARGV[i+1].match(/\d+,==|>=|<=|>|<$/).nil?
        raise ArgumentError
      end
      value, comparator = ARGV[i+1].split ','
      filters[arg == '-p' ? "points" : "comments"] = 
        ["%d", comparator, Integer(value)]
    elsif arg == '-t'
      if ARGV[1].nil? or ARGV[i+1].match(/\d+,==|>=|<=|>|<$/).nil?
        raise ArgumentError
      end
      time, unit, comparator = ARGV[i+1].split ','
      filters["time"] = ["%d", comparator, to_minutes(Integer(time), unit)]
    end
  end
rescue ArgumentError
  puts "Proper usage: $ ./hntoem.rb [filter options]\n" +
       "Filter options include a flag followed by a value, where the flag \n" +
       "identifies which field to filter on. Options include:\n" +
       "\t-p POINTS,[<[=] or >[=] or ==]      -->  Article must have [<[=] or" +
       " >[=] or ==] POINTS points\n" +
       "\t-c COMMENTS,[<[=] or >[=] or ==]    -->  Article must have [<[=] or" + 
       " >[=] or ==] COMMENTS comments\n" +
       "\t-t TIME,UNIT,[<[=] or >[=] or ==]   -->  Article must have been " +
       " posted [<[=] or >[=] or ==] TIME UNITs ago\n" +
       "\t                                         Examples: '-t 5,hour' or " +
       "'-t 15,minute' or '-t 2,day'\n" +
       "You can select any of these options for filtering.\nUsing no options " +
       "simply returns the front page of articles.\n"
  exit
end

#get front page HN article information as JSON
json = ''
open("http://api.ihackernews.com/page").each { |f| json << f }
articles = JSON.parse(json)['items']

#gather all headlines which meet filter requirements
headlines = []
articles.each do |a|
  points = a['points']
  comments = a['commentCount']
  begin
    time_ago = a['postedAgo'].match(/(.+) ago/).captures[0].split ' '
    time = to_minutes(Integer(time_ago[0]), time_ago[1])
  rescue NoMethodError, ArgumentError
    next
  end
  
  valid = true
  filters.each do |k, v|
    valid &&= eval("%d %s %d" % [v[0] % eval(k), v[1], v[2]])
  end
  
  if valid
    title = a['title']
    title_url = a['url']
    comments_url = 'http://news.ycombinator.com/item?id=%d' % a['id']
    
    headlines << Headline.new(title, title_url, points, comments,
                              comments_url, Integer(time_ago[0]), time_ago[1])
  end
end

#get email credentials from external file
email = ''
password = ''
address = ''
port = ''
File.open(File.join(File.dirname(__FILE__), 'credentials.txt'), 'r') do |f|  
  while line = f.gets  
    if !/^email/.match(line).nil?
      email = line.split(':')[1].strip 
    elsif !/^password/.match(line).nil?
      password = line.split(':')[1].strip
    elsif !/^address/.match(line).nil?
      address = line.split(':')[1].strip
    elsif !/^port/.match(line).nil?
      port = line.split(':')[1].strip
    end
  end  
end

#email filtered HN headlines to self
Pony.mail(:to => email, :via => :smtp, :via_options => {
    :address => address,
    :port => port,
    :enable_starttls_auto => true,
    :user_name => email,
    :password => password,
    :authentication => :plain,
},
:subject => 'HN to EM', :body => headlines) 

