#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

# =============================================================
# An example of Twitter bot by twbot2
# (old style; also available in version 0.20)
# 
# In the old style, the messages to be tweetes should be
# defined in 'load_data' method in the class inheriting
# 'TwBot'.
# Messages should be returned as an array of strings.
# (Array entries may be 'Array's or 'Hash'es; see the document)
# 
# This example is to fetch mentions to the bot and tweet the
# number of new mentions.
# =============================================================

$: << File.dirname(__FILE__)

require "./twbot2"
require "rubygems"
require "json"

class ReplyCounter < TwBot
  def load_data
    # ---------- fetch replies ----------
    
    # downloading the JSON
    response = auth_http.get("/1.1/statuses/mentions_timeline.json")
    json = JSON.load(response.body)
    
    # extracting only message IDs
    mentions_ids = json.elements.map{ |x| x["id"] }
    
    # ---------- exclude old replies ----------
    
    # If you create a new key in the Hash @config,
    # this will be kept automatically in the config file.
    @config['last_id'] ||= 0
    
    # keeping the newest ID among the downloaded mentions
    new_last_id = mentions_ids.first
    
    # excluding the IDs representing old messages
    mentions_ids.reject!{ |m_id| m_id < @config['last_id'] }
    
    # renewing the newest ID
    @config['last_id'] = new_last_id
    
    # ---------- return the message to be posted ----------
    # (as an array)
    ["#{mentions_ids.size} new replies found!"]
  end
end

self_path = File.dirname(__FILE__)
ARGV.each do |mode|
  ReplyCounter.new mode, "#{self_path}/config-countreplies.yml", "#{self_path}/error-countreplies.log"
end
