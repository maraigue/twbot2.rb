require "./twbot2"
TwBot.create("config-file.yml", "log-file.log").cui_menu do
  # Define what the bot talks here
  tweet_list = ["Good morning", "Good afternoon", "Good evening"]
  [tweet_list[rand(tweet_list.size)]] # return as an array
end
