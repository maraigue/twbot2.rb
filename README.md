# NOTICE (2024-06-08)

**twbot2.rb is now unavailable due to changes in API uses in Twitter (X).**  
**Please use [twbot3.rb](https://github.com/maraigue/twbot3.rb) for new bot creations.**

# About twbot2.rb

**twbot2.rb** is a Twitter bot framework combined with OAuth token manager.

Since version 0.21, the program was remade to be used non-Twitter-bot Twitter program, where twbot2.rb works as only an OAuth token manager.

## 日本語での説明 (in Japanese)

http://maraigue.hhiro.net/twbot/ または https://github.com/maraigue/twbot2.rb/wiki をご覧ください。

# Installation

    gem install json    # needed in Ruby 1.8 or before
    gem install oauth
    gem install devnull

Then, download twbot2.rb here and put it in the same directory as the bot program's location.

## Needed with version 0.23 or later

Until version 0.22, the application key/secret (application-specific strings needed for accessing Twitter API) for twbot2.rb is sepcified by default.  
Since version 0.23, it is not specified by default since Twitter will introduce the limitation of tweets per application (in addition to the existing limitation of tweets per account) on September 10th, 2018.  
[New developer requirements to protect our platform (Developer Blog, Twitter)](https://blog.twitter.com/developer/en_us/topics/tools/2018/new-developer-requirements-to-protect-our-platform.html)

1.  [Register an application for Twitter](https://apps.twitter.com/). Then retrieve the pair of "Consumer Key" and "Consumer Secret".  
2.  Open twbot2.rb, find the code `set_consumer("", "")`, and then input the key and the secret here.

For just trial, instead of registering the application, use the code described in the comment.

# Example

We have only to define what the bot tweets as the following format:

    $ cat greeting_bot.rb
    
    require "./twbot2"
    TwBot.create("config-file.yml", "log-file.log").cui_menu do
      # Define what the bot tweets here
      tweet_list = ["Good morning", "Good afternoon", "Good evening"]
      
      # Since it has to return tweets as an array,
      # To tweet only once, it should return a single-element array
      [tweet_list[rand(tweet_list.size)]] 
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

# Copyrights

The original author, H.Hiro(Maraigue), distributes the library under "new BSD License". You may re-distribute a modified library as long as the original version's license text is included (details are shown in LICENSE.txt).

# Contact

Original author: H.Hiro(Maraigue) (e-mail: main at hhiro.net, website: http://hhiro.net/)

To request new features and/or bug fixes, contact the e-mail address or send a pull request via GitHub (https://github.com/maraigue/twbot2.rb/).
