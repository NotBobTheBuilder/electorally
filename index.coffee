Twitter = require('twit')
t = new Twitter
    consumer_key:           process.env.TWITTER_CONSUMER_KEY
    consumer_secret:        process.env.TWITTER_CONSUMER_SECRET
    access_token:           process.env.TWITTER_TOKEN
    access_token_secret:    process.env.TWITTER_TOKEN_SECRET

database =
    users: {}
    constituencies: require('./postcodes.json')
    parties: ["lib", "lab", "con"]
    constituency_voting: {}
    constituency_mightvote: {}

stream = t.stream('user')

stream.on 'follow', (data) ->
    follower = data.source.id
    t.post 'friendships/create', { id: follower }, ->
        message =
            user_id: follower
            text: "Ready to vote better? Lets get started! Enter the name of your constituency"
        t.post 'direct_messages/new', message, ->
            database.users[follower] =
                id: follower
                state: 0

stream.on 'direct_message', (data) ->
    return if data.direct_message.sender.id_str is process.env.ELECTORALLY_APP_ID

    findConstituency = (name, user) ->
      constituency = database.constituencies.filter( (c) -> c.constituency is name)[0]
      message =
          user_id: user.id
          text: "OK, you're voting in #{constituency.constituency}, #{constituency.area}. Who are you voting for?"
      user.constituency = constituency.constituency
      t.post 'direct_messages/new', message, ->
          database.users[user.id].state = 1

    getMainParty = (party, constituency) ->
      database.constituency_voting[constituency] or= {}
      database.constituency_voting[constituency][party] or=0
      database.constituency_voting[constituency][party]++
      voters = database.constituency_voting[constituency][party]
      message =
          user_id: user.id
          text: "#{voters} voters are voting #{party} in #{constituency}. Who do you want to vote for?"
      database.users[user.id].constituency = constituency
      t.post 'direct_messages/new', message, ->
          database.users[user.id].state = 2

    getNextParty = (party, constituency) ->
      database.constituency_mightvote[constituency] or= {}
      database.constituency_mightvote[constituency][party] or=0
      database.constituency_mightvote[constituency][party]++
      voters = database.constituency_mightvote[constituency][party]
      message =
          user_id: user.id
          text: "#{voters} voters want to vote #{party} in #{constituency}. I'll tell you if there's support"
      t.post 'direct_messages/new', message, ->
          database.users[user.id].state = 2

    user = database.users[data.direct_message.sender.id_str]
    switch user.state
      when 0 then findConstituency(data.direct_message.text, user)
      when 1 then getMainParty(data.direct_message.text, user.constituency)
      when 2 then getNextParty(data.direct_message.text, user.constituency)
