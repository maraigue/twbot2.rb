#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require "./twbot2"

# Example: show the name of the authenticated user
# 
# To run the example,
# - First try "ruby twbot3.rb run". The content in the block
#   (extracting authenticated user) will be conducted and probably
#   results in the message you are not authenticated.
# - Then try "ruby twbot3.rb init". A dialog will appear to
#   authenticate you. (You need a browser)
# - Finally try "ruby twbot3.rb run" again. A message you have
#   been authenticated will be shown.

TwBot.create("config-apiaccess.yml", "error-apiaccess.log").cui_menu do
  # Define what to do in the block for TwBot#cui_menu.
  json_src = auth_http.get("/1.1/account/verify_credentials.json").body
  data = JSON.load(json_src)
  puts "You are authenticated as @#{data["screen_name"]}."
end
