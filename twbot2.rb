#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# ------------------------------------------------------------
# twbot2.rb - Twitter Bot Support Library in Ruby
# version 0.23
#
# (C)2010- H.Hiro(Maraigue)
# * mail: main@hhiro.net
# * web: http://maraigue.hhiro.net/twbot/
# * Twitter: http://twitter.com/h_hiro_
#
# This library is distributed under the (new) BSD license.
# See the file LICENSE.txt .
# ------------------------------------------------------------

require 'devnull'
require 'yaml'
require 'oauth'
require 'json'
#YAML::ENGINE.yamler = 'syck'

class Exception
  def twbot_errorlog_format
    "#{self.class}: #{self}\n"+self.backtrace.map{ |x| "\t#{x}" }.join("\n")
  end
end

class TwBot
  # Consumer token of twbot2.rb
  # If you want to use this code for another application,
  # change the values of consumer key/secret to your application's ones.
  
  def self.set_consumer(key, secret, site = 'https://api.twitter.com')
    if key.to_s.empty? || secret.to_s.empty?
      STDERR.puts <<ERROR
============================================================
*** ERROR in application key/secret ***

What you have to do:
1. Issue application key/secret in Twitter site.
   https://apps.twitter.com/
2. At the following part in twbot2.rb file:
   set_consumer("", "")
   specify the application key/secret here.
For just trial, use the sample code in twbot2.rb file.
============================================================
ERROR
      raise ArgumentError, "Invalid application key/secret"
    end
    @@consumer = OAuth::Consumer.new(key, secret, :site => site)
  end
  set_consumer("", "")
  # For just trial, use
  #set_consumer("GcgsfkmFsT6THBOO9Qw", "wgBJ8OPgQqyc8T8SArYkavvCDoIW2jh2K12jl4Qf8")
  
  def self.consumer
    @@consumer
  end
  
  # ------------------------------------------------------------
  #   Instance methods
  # ------------------------------------------------------------
  
  # constructor
  def self.create(config_file, log_file = nil, list = '', keep_config = false, test = false)
    self.new(nil, config_file, log_file, list, keep_config, test)
  end
  
  def initialize(mode, config_file, log_file = nil, list = '', keep_config = false, test = false)
    if log_file.kind_of?(Hash)
      # If arguments are specified by a Hash
      list = log_file.fetch(:list, "")
      keep_config = log_file.fetch(:keep_config, false)
      test = log_file.fetch(:test, false)
      
      log_file = log_file.fetch(:log_file, nil)
    end
    
    if File.exist?(config_file)
      @config_file_obj = open(config_file, "r+b")
      @config_file_obj.flock(File::LOCK_EX)
      @config = YAML.load(@config_file_obj.read)
    else
      STDERR.puts "Warning: Configuration file \"#{config_file}\" not found: newly created."
      @config_file_obj = open(config_file, "a+b")
      @config_file_obj.flock(File::LOCK_EX)
    end
    @config = {} unless @config.kind_of?(Hash)
    
    @config_file = config_file
    @log_file = log_file
    @list = "data/#{list}"
    @keep_config_default = keep_config
    @keep_config = keep_config
    @test = test
    
    @logmsg = ""
    
    action_by_mode(mode, nil) if mode
  end
  
  def cui_menu_error
    STDERR.puts <<-BUF
Usage: #{$0} [modes...]

'modes' should be one of the followings:

- init:           Initializes the configuration file by an authenticated
                  user. (Browser needed)
- add[=USER]:     Adds an authenticated user to the configuration file.
                  (Browser needed)
- refresh[=USER]: Same as "add[=USER]", but always tries authentication
                  even if the USER is in the configuration file.
- default[=USER]: Set the default authenticated user as USER.
- run[=OPTSTR]:   Runs specified code.
                  OPTSTR is given as the variable @optstr in the code.
- load[=OPTSTR]:  Runs specified code as a Twitter bot definition; the
                  returned values (must be an array) are stored as
                  tweets into the configuration file.
                  OPTSTR is given as the variable @optstr in the code.
- post[=COUNT]:   Posts tweets stored by "load" mode.

Example:
  #{$0} init
  #{$0} add
  #{$0} add=h_hiro_
  #{$0} run
  #{$0} load
  #{$0} post=10
    BUF
  end
  
  def cui_menu(&block)
    if ARGV.empty?
      cui_menu_error
      return
    end
    
    ARGV.each do |mode|
      STDERR.puts "Running mode '#{mode}'..."
      @logmsg << "\n[cui_menu:mode=#{mode}]"
      
      action_by_mode(mode, block)
    end
  end
  
  def action_by_mode(mode, block)
    @last_run_mode = mode
    begin
      case mode
      when "init"
        init
      when /\Aadd(?:=([0-9A-Z_a-z]+))?\z/
        add_user($1, false)
      when /\Arefresh(?:=([0-9A-Z_a-z]+))?\z/
        add_user($1, true)
      when /\Adefault(?:=([0-9A-Z_a-z]+))?\z/
        default_user($1)
      when /\Arun(?:\=(.*?))?\z/
        @optstr = $1
        run(&block)
      when /\Aload(?:\=(.*?))?\z/
        @optstr = $1
        load_tweet(&block)
      when /\Apost(?:=(\d+)(?:,(\d+))?)?\z/
        # post messages from the list
        post_count = ($1 ? $1.to_i : 1)
        retries = ($2 ? $2.to_i : 0)
        post_tweet(post_count, retries)
      else
        cui_menu_error
        @logmsg << "Error: Invalid mode"
        @keep_config = true
        save_config
        return
      end
    rescue Exception => e
      @logmsg << "<Error>"+e.twbot_errorlog_format+"\n"
      @keep_config = true
      save_config
    end
  end
  
  def run(&block)
    instance_eval(&block)
    save_config
  end
  
  # Add new messages to be tweeted.
  # Usage: twbot_instance.load_tweet{ an_array_of_tweets }
  def load_tweet(&block)
    @config[@list] ||= []
    
    begin
      if block
        new_updates = instance_eval(&block)
      else
        new_updates = load_data
      end
      new_updates.each do |m|
        if TwBot.validate_message(m) == nil
          raise MessageFormatError, "Invalid object as a message is contained: #{m.inspect}"
        end
      end
    rescue Exception => e
      @logmsg << "<Error> "+e.twbot_errorlog_format+"\n"
      @keep_config = true
    else
      @config[@list].concat new_updates
    end
    save_config
  end
  
  # Tweet loaded messages.
  def post_tweet(post_count = 1, retries = 0, user = @config["login/"], list = @list)
    while post_count > 0
      begin
        break if update_from_list(:user => user, :list => list, :duplicated => @config['duplicated/']) == nil
      rescue Exception => e
        @logmsg << "<Error in updating> #{e}\n"+e.twbot_errorlog_format+"\n"
        retries -= 1
        
        break if retries < 0
        redo
      end
      
      post_count -= 1
    end
    save_config
  end
  
  # Add a new user.
  # If 'reload' is specified true, a token will be re-retrieved.
  def add_user(username, reload = false, update_default = false)
    until username
      print "User name >"
      STDOUT.flush
      username = STDIN.gets.chomp
      return if username.empty?
      redo unless username =~ /\A[0-9A-Z_a-z]+\z/
    end
    
    if !reload && user_registered?(username)
      puts "The user \"#{username}\" is already registered."
      return
    end
    
    auth = auth_http(:user => username, :reload => reload, :browser => true)
    if auth != nil
      puts "User \"#{username}\" is successfully registered."
      if update_default || @config["login/"] == nil
        @config["login/"] = username
        puts "Default user is set to @#{username}."
      end
    end
    save_config
  end
  
  def default_user(username)
    @config["login/"] ||= nil
    if @config["login/"]
      print "Current default user is @#{@config["login/"]}."
    end
    unless username
      print "Input new default user name."
    end
    add_user(username, false, true)
  end
  
  def init
    if @config["login/"]
      # If default login user is already registered
      # (updating from twbot.rb 0.1*)
      puts <<-OUT
============================================================
Here I help you retrieve OAuth token of user "#{@config['login/']}".
Please prepare a browser to retrieve OAuth tokens.
============================================================
      OUT
        
      add_user(@config["login/"], true)
    else
      # Otherwise
      puts <<-OUT
============================================================
Here I help you register your bot account to the setting file.
Please prepare a browser to retrieve OAuth tokens.

Input the screen name of your bot account.
============================================================
      OUT
        
      add_user(nil, true)
    end
  end
  
  def save_config
    unless @keep_config
      new_yaml = YAML.dump(@config)
      @config_file_obj.rewind
      @config_file_obj.print new_yaml
    end
    @keep_config = @keep_config_default
    
    # output log
    @logmsg = "[#{Time.now}]#{@last_run_mode ? '(mode='+@last_run_mode+')' : ''}#{@logmsg}"
    STDERR.puts @logmsg
    
    if @log_file
      begin
        open(@log_file, "a") do |f|
          f.puts @logmsg
          @logmsg = ""
        end
      rescue Exception => e
        STDERR.puts e.twbot_errorlog_format
      end
    end
  end
  
  # update
  def update_from_list(info = @config["login/"])
    # parse parameters
    case info
    when String
      # If the parameter is given by a string,
      # It is treated as the user name
      user = info
      list = @list
      duplicated = "ignore"
    when Hash
      user = info.fetch(:user, @config["login/"])
      list = info.fetch(:list, @list)
      duplicated = info.fetch(:duplicated, @config['duplicated/']).to_s
      duplicated = "ignore" if duplicated == ""
    else
      raise ArgumentError, "A String (user name) or Hash (parameters) is required as the argument (#{info.class} given)"
    end
    
    # post messages
    auth = auth_http(user)
    
    trial = 0
    while true
      trial += 1
      
      # prepare the message
      if @config[list].empty?
        error_message = "(error: No message remains)"
        STDERR.puts error_message
        @logmsg << error_message
        return nil
      end
      
      message = @config[list].first
      request = TwBot.validate_message(message)
      raise MessageFormatError, message.inspect if request == nil
      
      if request[:status].empty?
        # If empty string is specified
        @config[list].shift
        @logmsg << "(skipped: An empty string specified)"
        return false
      end
      request[:status].force_encoding("utf-8")
      
      # send request
      if @test
        result = "[]" # dummy json
      else
        result = auth.post("/1.1/statuses/update.json", request).body
      end
      
      # Check the result
      json_parsed = true
      begin
        JSON.load(result)
      rescue 
        json_parsed = false
      end
      unless json_parsed
        # if failed
        if result.index("\"Status is a duplicate.\"")
          # if duplicated
          error_message = "(error: The status \"#{request[:status]}\" is not posted because of duplication)"
          STDERR.puts error_message
          @logmsg << error_message
            
          case duplicated
          when "seek"
            tmp = @config[list].shift
            @config[list].push tmp
          when "discard"
            @config[list].shift
            trial -= 1
          when "cancel"
            return false
          when "ignore"
            @config[list].shift
            return false
          end
        else
          # if another reason
          raise RuntimeError, "Posting a tweet has failed - JSON data is:\n#{result}"
        end
      else
        # if succeeded
        
        # renew lists
        @config[list].shift
        
        # outputing / writing log
        STDERR.puts "[Updated!#{@testmode ? '(test)' : ''}] #{request[:status]}"
        @logmsg << "(A tweet has been posted)"
        return result
      end
      
      return false if trial >= @config[@list].size
    end
  end
  
  # check the user is registered in the config file
  # returns true if and only if registered with OAuth token
  def user_registered?(user)
    user_key = "users/#{user}"
    @config[user_key] && @config[user_key]["token"] && @config[user_key]["secret"]
  end
  
  # Returns access token.
  # HTTP access with registered OAuth token can be done like:
  #   auth_http.get(path...)
  #   auth_http.post(path...)
  #   auth_http(user).get(path...)
  def auth_http(info = @config["login/"])
    # parse parameters
    case info
    when String
      # If the parameter is given by a string,
      # It is treated as the user name
      user = info
      reload = false
      browser = false
    when Hash
      user = info.fetch(:user, @config["login/"])
      reload = info.fetch(:reload, false)
      browser = info.fetch(:browser, false)
    else
      errmsg = "A String (user name) or Hash (parameters) is required as the argument (#{info.class} given)"
      if info == nil
        errmsg << "\n* Perhaps you have not finished authentication. Try '#{$0} init' to register the default user."
      end
      raise ArgumentError, errmsg
    end
    
    # creates an instance of AccessToken
    user_key = "users/#{user}"
    @config[user_key] ||= {}
    
    if reload || !(user_registered?(user))
      # if token is not stored, or the library user choosed not to use stored token,
      # retrieves it with xAuth or browser
      if browser
        # with browser
        access_token = TwBot.access_token_via_browser(user)
      else
        # with xAuth
        # 
        # Note:
        # TwBot is not allowed to use xAuth for now.
        # "TwBot.access_token_via_xauth" will always return HTTP 401 error.
        # (2010-04-30)
        unless @config[user_key]["password"]
          if user == @config["login/"]
            @config[user_key]["password"] = @config["password/"]
          else
            raise IncompleteConfigError, "Password for user \"#{user}\" is not specified."
          end
        end
        
        access_token = TwBot.access_token_via_xauth(user, @config[user_key]["password"])
      end
      
      return nil if access_token == nil
      
      # Store the result to @config
      @config[user_key]["token"] = access_token.token
      @config[user_key]["secret"] = access_token.secret
      
      # return the access token
      access_token
    else
      # if token is stored, creates access token with it
      OAuth::AccessToken.new(@@consumer, @config[user_key]["token"], @config[user_key]["secret"])
    end
  end
  
  # get followers as both screen names and user IDs
  def get_followers(auth = auth_http())
    TwBot.followers_of(auth)
  end
  
  # get friends as both screen names and user IDs
  def get_friends(auth = auth_http())
    TwBot.friends_of(auth)
  end
  
  # get followers as only user IDs
  def get_followers_ids(auth = auth_http())
    TwBot.followers_ids(auth)
  end
  
  # get friends as only user IDs
  def get_friends_ids(auth = auth_http())
    TwBot.friends_ids(auth)
  end
  
  # follow a user
  def check_follow_result(message, http_result)
    begin
      (JSON.load(http_result.body))["id"]
    rescue Exception => e
      raise RuntimeError, "#{message}: HTTP result is\n#{http_result.body}"
    end
  end
  private :check_follow_result
  
  def follow_by_screen_name(target_user, auth = auth_http())
    check_follow_result "Failed in following @#{target_user}", auth.post("/1.1/friendships/create.json", :screen_name => target_user)
  end
  alias :follow :follow_by_screen_name
  
  def follow_by_user_id(target_user, auth = auth_http())
    check_follow_result "Failed in following UserID:#{target_user}", auth.post("/1.1/friendships/create.json", :user_id => target_user.to_s)
  end
  
  # unfollow a user
  def check_unfollow_result(message, http_result)
    begin
      (JSON.load(http_result.body))["id"]
    rescue Exception => e
      raise RuntimeError, "#{message}: HTTP result is\n#{http_result.body}"
    end
  end
  private :check_unfollow_result
  
  def unfollow_by_screen_name(target_user, auth = auth_http())
    check_unfollow_result "Failed in unfollowing @#{target_user}", auth.post("/1.1/friendships/destroy.json", :screen_name => target_user)
  end
  alias :unfollow :unfollow_by_screen_name
  
  def unfollow_by_user_id(target_user, auth = auth_http())
    check_unfollow_result "Failed in unfollowing UserID:#{target_user}", auth.post("/1.1/friendships/destroy.json", :user_id => target_user.to_s)
  end
    
  # get following status
  def following_status(target_user, auth = auth_http())
    result = auth.get("/1.1/friendships/show.json?target_screen_name=#{target_user}")
    
    json = JSON.load(result.body)
    {:following => json["relationship"]["source"]["following"],
     :followed => json["relationship"]["source"]["followed_by"]}
  end
  
  # ------------------------------------------------------------
  #   Class methods (Utilities)
  # ------------------------------------------------------------
  
  # Separates reply string ("@USERNAME") into "@ USERNAME"
  # to avoid unintended replies.
  # If a block is given, "@USERNAME" is separated if the result
  # of the block is true.
  def self.remove_reply(str)
    result = str.dup
    result.gsub!(/(@|＠)([0-9A-Z_a-z]+)/) do |x|
      at_mark = $1
      user_id = $2
      if block_given?
        (yield(user_id) ? "#{at_mark} #{user_id}" : x)
      else
        "#{at_mark} #{user_id}"
      end
    end
    
    result.gsub!(/#/){ |x| "# " }
    
    result
  end
  
  # Truncate the end of the string if it is longer than max_length
  # Footer can be added
  #   Twbot.truncate_to_length(5, "foobar", "...") #=> "fo..."
  def self.truncate_to_length(max_length, source, footer = "")
    return source if source.length <= max_length
    "#{source[0, max_length - footer.length]}#{footer}"
  end
  
  # If the specified string is "true" or "false" (case insensitive),
  # returns that boolean value. Otherwise raises an exception.
  def self.parse_boolean(str)
    case str
    when /\Atrue\z/i
      true
    when /\Afalse\z/i
      false
    else
      raise ArgumentError, "Value is neither of 'true' nor 'false'"
    end
  end
  
  # Converts values from user-defined "load_post" method
  # into HTTP request.
  # Returns nil if the value is invalid.
  def self.validate_message(obj)
    case obj
    when String
      {:status => obj}
    when Array
      return nil if obj.size != 2
      {:status => obj[0], :in_reply_to_status_id => obj[1].to_s}
    when Hash
      obj
    else
      nil
    end
  end
  
  # Get OAuth token (via xAuth)
  def self.access_token_via_xauth(username, password)
    @@consumer.get_access_token(nil, {}, {
      :x_auth_mode => "client_auth",
      :x_auth_username => username,
      :x_auth_password => password})
  end
  
  # Get OAuth token (via browser)
  def self.access_token_via_browser(username)
    # ref: http://d.hatena.ne.jp/shibason/20090802/1249204953
    
    request_token = @@consumer.get_request_token
    
    puts <<-OUT
============================================================
To retrieve OAuth token of user "#{username}":
(1) Log in Twitter with a browser as user "#{username}".
(2) Access the URL below with the browser:
    #{request_token.authorize_url}
(3) Check that the application name displayed in the page is
    the same as the one specified in this twbot2.rb file.
    If so, click "Allow" link in the browser.
    (Information of the application in this twbot2.rb file:
     KEY=#{@@consumer.key}
     SECRET=#{@@consumer.secret})
(4) Input the shown number (PIN number).
    To cancel, input nothing and press enter key.
============================================================
    OUT
    
    pin_number = nil
    begin
      print "PIN number >"
      STDOUT.flush
      pin_number = STDIN.gets.chomp
    end until pin_number && pin_number =~ /\A\d*\z/
    
    return nil if pin_number == ""
    
    request_token.get_access_token(:oauth_verifier => pin_number)
  end
  
  # Retrieves users where the API returns paginated user list.
  # (ex. http://api.twitter.com/1/statuses/friends)
  # 
  # Stops retriving if API calls has failed for retry_count times.
  # 
  # The result is returned by a Hash of following format:
  # {:result => ["user1", "user2", ...],
  #  :gained_result => ["user1", "user2", ...],
  #  :id => [id1, id2, ...],
  #  :gained_id => [id1, id2, ...],
  #  :error => [exception1, exception2, ...]}
  #
  # :result and :gained_result represent the screen names,
  # while :id and :gained_id represent the users' ID numbers.
  # 
  # If API calls has failed for retry_count times,
  # :result and :id are both nil,
  # while :gained_result and :gained_id are both partial result.
  # 
  # Note that /1.1/followers/ids and /1.1/friends/ids
  # do not return either :gained_result or :result (empty array).
  def self.paginated_user_list(path, auth, retry_count = 3)
    user_list = []
    id_list = []
    all_list = []
    error_list = []
    cursor = "-1"
    
    while true
      begin
        STDERR.puts "Downloading #{path} (cursor ID: #{cursor})"
        
        # Download users
        if path.index("?")
          new_path = "#{path}&cursor=#{cursor}"
        else
          new_path = "#{path}?cursor=#{cursor}"
        end
        json_source = auth.get(new_path).body
        
        json = JSON.load(json_source)
        if json["errors"]
          raise "Error from Twitter API - #{json.inspect}"
        end
        
        if json["users"]
          all_list.concat(json["users"])
          user_list.concat(json["users"].map{ |u| u["screen_name"] })
          id_list.concat(json["users"].map{ |u| u["id"] })
        elsif json["ids"]
          id_list.concat(json["ids"])
        end
        
        # Get the cursor to the next page
        tmp = json["next_cursor"]
        unless tmp
          raise RuntimeError, "Pagination of #{path} has failed"
        end
        cursor = tmp
        STDERR.puts "Downloading finished (\#UserID: #{id_list.size}, next cursor ID: #{cursor})"
        
        break if cursor == 0
      rescue Exception => e
        STDERR.puts e.twbot_errorlog_format
        
        error_list << e
        retry_count -= 1
        break if retry_count <= 0
      end
    end
    
    {:gained_result => user_list,
     :gained_id => id_list,
     :gained_all => all_list,
     :result => (retry_count <= 0 ? nil : user_list.dup),
     :id =>     (retry_count <= 0 ? nil : id_list.dup),
     :all =>    (retry_count <= 0 ? nil : all_list.dup),
     :error => error_list}
  end
  
  def self.followers_of(auth = auth_http(), retry_count = 3)
    paginated_user_list("/1.1/followers/list.json?skip_status=true&include_user_entities=false", auth, retry_count)
  end
  
  def self.friends_of(auth = auth_http(), retry_count = 3)
    paginated_user_list("/1.1/friends/list.json?skip_status=true&include_user_entities=false", auth, retry_count)
  end
  
  def self.followers_ids(auth = auth_http(), retry_count = 3)
    paginated_user_list("/1.1/followers/ids.json", auth, retry_count)
  end
  
  def self.friends_ids(auth = auth_http(), retry_count = 3)
    paginated_user_list("/1.1/friends/ids.json", auth, retry_count)
  end
  
  def self.user_details(id_list, auth = auth_http())
    if id_list.length > 100
      raise ArgumentError, "Number of user IDs must be 100 or less"
    end
    
    JSON.load(auth.get("/1.1/users/lookup.json?user_id=#{id_list.map{|x| x.to_s }.join(',')}").body)
  end
  # ------------------------------------------------------------
  #   Exceptions
  # ------------------------------------------------------------
  
  # Raised when a lack of information is found in config file
  class IncompleteConfigError < RuntimeError
  end
  
  # Raised when the elements of array returned from load_data() is invalid
  class MessageFormatError < RuntimeError
  end
end
