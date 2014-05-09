async = require 'async'
moment = require 'moment'

###

下毒规则：

毒到自己阵营：
    1. [DESTROY RESONATOR] markup.PLAYER1.team == markup.PORTAL1.team

毒到对方阵营：
    1. 两次时间相邻的DESTROY RESONATOR，markup.PORTAL1.team不一致，且中间没有capture   -> 两次之间有毒
    2. 两次中最近一次不符合“毒到自己阵营”                                              -> 最近一次被毒到对方阵营

###

get_portal_history = (req, res) ->

    guid = req.params.guid
    minTimestampMs = parseInt(req.params.mintimestampms)

    Database.db.collection('Chat.Public').find
        'markup.PORTAL1.guid': guid
        'time':
            $gte: minTimestampMs
    .sort {time: -1}, (err, cursor) ->

        response = []

        lastDestroyEvent = null
        lastCaptureEvent = null

        next = ->

            setImmediate ->
                cursor.nextObject p

        finish = ->

            res.json response

        p = (err, item) ->

            return finish() if item is null

            # flip to own faction
            
            if item.markup.TEXT1.plain is ' captured '
                lastCaptureEvent = item
                return next()

            if item.markup.TEXT1.plain is ' destroyed an '
                if item.markup.PLAYER1.team is item.markup.PORTAL1.team
                    response.push
                        time:    item.time
                        player:  item.markup.PLAYER1
                        event:   'flip'
                        event2:  if item.markup.PLAYER1.team is 'ENLIGHTENED' then 'Jarvis Virus' else 'ADA Refactor'
                        portal:  item.markup.PORTAL1
                
                if lastDestroyEvent?
                    if lastDestroyEvent.markup.PORTAL1.team isnt item.markup.PORTAL1.team and (lastCaptureEvent is null or lastCaptureEvent.time > lastDestroyEvent.time)
                        if lastDestroyEvent.markup.PLAYER1.team isnt lastDestroyEvent.markup.PORTAL1.team
                            response.push
                                time:    lastDestroyEvent.time
                                player:  lastDestroyEvent.markup.PLAYER1
                                event:   'flip'
                                event2:  if lastDestroyEvent.markup.PLAYER1.team is 'ENLIGHTENED' then 'ADA Refactor' else 'Jarvis Virus'
                                portal:  lastDestroyEvent.markup.PORTAL1

                lastDestroyEvent = item
                return next()

            next()

        next()

plugin = 

    name: 'portalhistory'

    init: (callback) ->

        Bot.Server.get '/portalhistory/:guid/:mintimestampms', AccessLevel.LEVEL_TRUSTED, 'Fetch the history of a protal', get_portal_history

        callback()

module.exports = plugin