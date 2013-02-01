# About twbot2.rb

**twbot2.rb** is a Twitter bot framework combined with OAuth token manager.

Since version 0.21, the program was remade to be used non-Twitter-bot Twitter program, where twbot2.rb works as only an OAuth token manager.

# Installation

    gem install json    # needed in Ruby 1.8 or before
    gem install oauth
    gem install devnull

Then, download twbot2.rb here and put it in the same directory as the bot program's location.

# Example

We have only to define what the bot tweets as the following format:

    $ cat greeting_bot.rb
    
    require "./twbot2"
    TwBot.create("config-file.yml", "log-file.log").cui_menu do
      # Define what the bot tweets here
      tweet_list = ["Good morning", "Good afternoon", "Good evening"]
      [tweet_list[rand(tweet_list.size)]] # return as an array
    end

To add the content to be tweeted to the configuration file, call with the parameter "load".

    $ ruby greeting_bot.rb load
    
    Running mode 'load'...
    [2000-00-00 00:00:00 +0000]
    [cui_menu:mode=load]

To post a tweet stored in "load" mode, call with the parameter "load".

    $ ruby greeting_bot.rb post
    
    Running mode 'post'...
    [2000-00-00 00:00:00 +0000]
    [cui_menu:mode=post]<Error in updating> A String (user name) or Hash
    (parameters) is required as the argument (NilClass given)
    * Perhaps you have not finished authentication. Try 'greeting_bot.rb init' to
    register the default user.
    ArgumentError: A String (user name) or Hash (parameters) is required as the
    argument (NilClass given)
    * Perhaps you have not finished authentication. Try 'greeting_bot.rb init' to
    register the default user.
    (snipped)

However, it fails since no user is registered in the configuration file yet. So let's initialize the configuration file with a default user.

    $ ruby greeting_bot.rb init
    
    Running mode 'init'...
    ============================================================
    Here I help you register your bot account to the setting file.
    Please prepare a browser to retrieve OAuth tokens.
    
    Input the screen name of your bot account.
    ============================================================
    User name >h_hiro_
    ============================================================
    To retrieve OAuth token of user "h_hiro_":
    (1) Log in Twitter with a browser for user "h_hiro_".
    (2) Access the URL below with same browser:
        https://api.twitter.com/oauth/authorize?oauth_token=****
    (3) Check the application name is "twbot2.rb" and
        click "Allow" link in the browser.
    (4) Input the shown number (PIN number).
        To cancel, input nothing and press enter key.
    ============================================================
    PIN number >*******
    User "h_hiro_" is successfully registered.
    Default user is set to @h_hiro_.
    [2000-00-00 00:00:00 +0000]
    [cui_menu:mode=init]

Then try again "post" mode. A tweet will be appear in Twitter.

    $ ruby greeting_bot.rb post
    
    Running mode 'post'...
    [Updated!] Good afternoon
    [2000-00-00 00:00:00 +0000]
    [cui_menu:mode=post](A tweet has been posted)

For more details, see the Wiki (https://github.com/maraigue/twbot2.rb/wiki).
