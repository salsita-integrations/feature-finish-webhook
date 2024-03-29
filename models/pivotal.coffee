Q = require('q')
request = require('request')
_ = require('lodash')

ROOT_URL = "https://www.pivotaltracker.com/services/v5"

getProjects = ->
  defer = Q.defer()
  options = {
    url: "#{ROOT_URL}/projects"
    json: true
    headers: {
      'X-TrackerToken': process.env.PT_TOKEN
    }
  }
  console.log options
  request options, (err, res, body) ->
    if err or res.statusCode != 200
      console.error 'getProjects error:', (err or body)
      return defer.reject(err or new Error(body))
    defer.resolve(body)
  return defer.promise


# Sets `current_state` of story with `storyId` to `state`.
#
# We don't have PT project id so we'll need to iterate over
# all the projects we have access to.
exports.setStoryState = (storyId, state) ->
  console.log 'PT setStoryState', storyId, state
  # Give me all the projects.
  getProjects()

    # Iterate over them and try to update story with `storyId`.
    # We'll get a HTTP 404 if the story doesn't belong to the project.
    .then (projects) ->
      console.log 'projects', (id for {id} in projects)
      qUpdates = _.map projects, (project) ->
        defer = Q.defer()
        options = {
          method: 'PUT'
          url: "#{ROOT_URL}/projects/#{project.id}/stories/#{storyId}"
          body: {current_state: state}
          json: true
          headers: {
            'X-TrackerToken': process.env.PT_TOKEN
          }
        }
        request options, (err, res, body) ->
          if err or res.statusCode != 200
            console.error "update story error:", (err or body)
            return defer.reject(err or new Error(body))
          defer.resolve(body)
        defer.promise
      # Get all promises regardless of their resolution state (so that we can
      # ignore errors).
      Q.allSettled(qUpdates)

    # We've pinged all the projects. Let's see if we succeeded.
    .then (settledPromises) ->
      console.log 'settled promises', settledPromises
      # Check if we have any resolved promises (i.e., update success).
      p = _.find settledPromises, state: "fulfilled"
      if not p
        console.log "No relevant story found..."
        return Q.reject({id: storyId})
      # Yay, updating story state succeeded!
      console.log "Story state updated!", p.value
      return Q("done")

    .fail (err) ->
      console.error "setStoryState error", err
      Q.reject(err)
