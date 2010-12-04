require 'rubygems'
require 'sinatra'
require 'twitter'
require 'haml'
require 'sequel'

# Database setup
DB = Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://ichl.db')
DB.create_table? :tweets do
  primary_key :id
  String :content
  BigNum :twitter_id, :type => :bigint
	DateTime :created_at
end
tweets = DB[:tweets]

# HAML config
set :haml, {:format => :html5, :attr_wrapper => '"' }

# main stylesheet
get '/css/screen.css' do
  header 'Content-Type' => 'text/css; charset=utf-8'
  css :screen
end

# homepage
get '/' do
  # get the max id from the database to pass to our search query
  since_id = tweets.max(:twitter_id)
  page = 1

	# Get the datetime of the earliest tweet
	#@since_date = ago_in_words(Date.strptime(tweets.max(:created_at), "%a, %d %b %Y %H:%M:%S +0000"))

  # load all the new tweets into the DB
  while true do
    @search = Twitter::Search.new('"internet explorer" OR ie6 OR ie7 OR ie8 shit OR piss OR fuck OR cunt OR arse OR arsehole OR ass OR asshole OR prick OR bastard')
    # 20 per page - twitter docs say 100, but seems to be less, so we
    # cover our bases for pagination. this pagination method also leaves
    # a small possibility of duplicates, but it's not a big deal.
    @search.per_page(20)
    @search.page(page)
    @search.since(since_id)
    item_count = 0

    @search.each do |item|
      tweets.insert(:twitter_id => item["id"].to_i, :content => item["text"], :created_at => item["created_at"])
      item_count = item_count + 1
    end
    # if we don't have more than 20 items, we can exit
    break if item_count < 20
    page = page + 1
  end
 
  @results = []

  @all_results = tweets.order(:twitter_id.desc).each do |item|
    # ignore items in the blacklist file or that start with rt/RT (retweets)
    unless BLACKLISTED_STRINGS.any? {|i| item[:content].downcase.match(i.downcase)} || item[:content].downcase.match(/^rt/)
      @results << item[:content].gsub(/^@\w[a-z]+\s/, '').
                                gsub(/((ftp|http|https):\/\/(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?)/i, '<a href="\1" rel="nofollow">\1</a>').
                                gsub(/(@\w[a-z]+)(\s|\S)/i, '<a href="http://twitter.com/\1">\1</a>').
                                gsub(/(Internet Explorer\W|ie[0-9]+\W?)/i, '<strong>\1</strong>').
                                gsub(/(shit\W|piss\W|fuck\W|cunt\W|arse\W|arsehole\W|ass\W|asshole\W|prick\W|bastard\W)/i, '<em>\1</em>')
    else
      #puts "This was blacklisted: #{item[:content]}"
    end
  end

  # Make heroku cache this page
  response.headers['Cache-Control'] = 'public, max-age=300'
    
  haml :index

end


# Configure Block.
configure do
  BLACKLISTED_STRINGS = []
  # read blacklist file.
  File.open(File.join(File.dirname(__FILE__), '/blacklist.txt'), 'r') do |file|
    while line = file.gets  
        BLACKLISTED_STRINGS << line.strip 
    end  
  end
end



