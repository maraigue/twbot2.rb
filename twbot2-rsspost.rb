#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# =============================================================
# An example of Twitter bot by twbot2
# (new style; available since version 0.21)
# 
# In the new style, the messages to be tweetes should be
# defined in the block attached to twbot2_instance#cui_menu
# method.
# Messages should be returned as an array of strings.
# (Array entries may be 'Array's or 'Hash'es; see the document)
# 
# Note that TwBot.new runs a bot code (because of backward
# compatibility; see also the example twbot2-countreplies.rb).
# To only create an instance, call TwBot.create method.
# 
# This example is to fetch an RSS and tweet the new entries.
# To run this program, use commands like these:
# ruby twbot2-rsspost.rb init        # Authenticate user to post the tweets
# ruby twbot2-rsspost.rb load        # Load RSS and add messages to the list
# ruby twbot2-rsspost.rb post        # Post one message in the list
# ruby twbot2-rsspost.rb post post   # Post two messages in the list
# ruby twbot2-rsspost.rb load post   # Load RSS and add messages to the list,
#                                    # and post one message in the list
# =============================================================

RSS_URL = "http://d.hatena.ne.jp/maraigue/rss"

require "cgi"
require "open-uri"
require "./twbot2"

SELFDIR = File.dirname(__FILE__)
TwBot.create("#{SELFDIR}/config-rsspost.yml", "#{SELFDIR}/error-rsspost.log").cui_menu do
  # Download RSS
  buf = nil
  open(RSS_URL){ |file| buf = file.read }
  
  result = []
  @config["already_retrieved"] ||= ""
  newest_entry = false
  
  # Retrieve entries in RSS
  # (It is better to use REXML library; this program omits it
  #  for simpleness.)]
  buf.scan(/<item.*?>.*?<\/item>/m).each do |entry|
    # Extract titles and URLs of entries from downloaded RSS
    title = nil
    entry.scan(/<title>(.*?)<\/title>/){|tmp| title = CGI.escapeHTML(tmp[0])}
    link = nil
    entry.scan(/<link>(.*?)<\/link>/){|tmp| link = CGI.escapeHTML(tmp[0])}
    
    # Ignore entries already retrieved by this program
    # 
    # NOTE: @config["..."] values are kept for the next running
    #       of the program.
    break if link == @config["already_retrieved"]
    
    # Adds a message to the list to be tweeted later.
    # 
    # Because RSS stores entries from newer one, to post messages in the
    # original order, the message have to be added to the bottom of the
    # array 'result'.
    result.unshift(TwBot."[AUTO POST] #{link} #{title}") if title && link
    
    # Keep the URL of the newest entry in the data retrieved now
    unless newest_entry
      newest_entry = true
      @config["already_retrieved"] = link
    end
  end
  
  
  # Set logged message
  @logmsg = "(#{result.size} post added)"
  
  # Return the result
  # 
  # NOTE: the returned value must be an array of tweets when a bot
  #       is constructed (called by 'ruby SCRIPTNAME.rb load')
  result
end
