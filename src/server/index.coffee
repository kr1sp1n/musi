debug = require('debug')('musi')

options = 
  appkeyFile: "#{__dirname}/../../config/spotify_appkey.key"
  cacheFolder: 'tmp/cache'
  settingsFolder: 'tmp/settings'

spotify = require("#{__dirname}/../../lib/spotify")(options)

current_track = null
playlists = null

playTrack = (track)->
  debug 'start playing %s', track.name
  current_track = track
  spotify.player.play track

play = (obj, done)->
  debug obj
  # is playlist?
  if obj.numTracks?
    playlist = obj
    debug 'get first track of playlist %s', playlist.name
    track = playlist.getTracks()[0]
    track.position = 0
    debug 'loading track %s...', track.name
    unless track?.isLoaded
      spotify.waitForLoaded [track], (track)->
        debug '...done'
        playTrack track
        done null, track
    else
      debug '...already loaded'
      playTrack track
      done null, track

ready = ->
  debug '...spotify ready'
  playlists = spotify.playlistContainer.getPlaylists()


spotify.on ready: ready
user = require "#{__dirname}/../../config/spotify_user"
debug 'login to spotify...'
spotify.login user.name, user.password, false, false


fetch_playlist = (id, done)->
  playlist = playlists[id]
  debug 'loading playlist %s ...', playlist.name
  debug '...already loaded' if playlist?.isLoaded
  unless playlist?.isLoaded
    spotify.waitForLoaded [playlist], (playlist)->
      debug '...done'
      done null, playlist
  else
    done null, playlist

fetch_tracks = (playlist, done)->
  tracks = playlist.getTracks()
  count = tracks.length
  i = 0
  spotify.waitForLoaded tracks, (track)->
    i++
    return done null, tracks if i == count

express = require 'express'
app = express()
app.use express.static("#{__dirname}/../client")


app.get '/stop', (req, res)->
  if current_track?
    track = current_track
    artist = track.artists[0].name
    spotify.player.stop()
    res.send "STOP\n\n#{artist} - #{track.name}"
  else
    res.send "No current track"

app.get '/search', (req, res)->
  search = new spotify.Search('godspeed you black emperor', 2, 10)
  search.execute (err, result)->
    console.log result
    res.send 'hello'

app.get '/playlist/:id', (req, res)->
  id = Number(req.params.id)
  debug 'GET /playlist/%s', id
  fetch_playlist id, (err, playlist)->
    debug err if err
    fetch_tracks playlist, (err, tracks)->
      result = ({id: index, name: track.name, artist: track.artists[0].name} for track, index in tracks)
      res.format
        text: ->
          tracks = ("#{x.id}) #{x.artist} - #{x.name}" for x in result)
          res.send "#{playlist.name}\n\n#{tracks.join('\n')}\n"


app.get '/playlist/:id/play', (req, res)->
  id = Number(req.params.id)
  debug 'GET /playlist/%s/play', id
  fetch_playlist id, (err, playlist)->
    debug err if err
    play playlist, (err, track)->
      debug err if err
      res.send "PLAY FROM #{playlist.name}\n\n#{track.artists[0].name} - #{track.name}"

app.get '/playlist', (req, res)->
  debug 'GET /playlist'
  result = ({id: index, name: list.name} for list, index in playlists)
  res.format
    text: ->
      lists = ("#{x.id}) #{x.name}" for x in result)
      res.send lists.join('\n') + '\n'
    html: ->
      items = ("<li>#{x.name}</li>" for x in result)
      res.send '<h2>Your Playlists</h2><ul>' + items.join('\n') + '</ul>'
    json: ->
      res.send title: 'Your Playlists', items: result

app.listen 3000