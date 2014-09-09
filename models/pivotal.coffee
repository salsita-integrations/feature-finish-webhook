Q = require('q')
sa = require('superagent')
_ = require('lodash')

ROOT_URL = "https://www.pivotaltracker.com/services/v5"

getProjects = ->
  defer = Q.defer()
  sa
    .get("#{ROOT_URL}/projects")
    .set('X-TrackerToken', process.env.PT_TOKEN)
    .end (err, res) ->
      if err or not res.ok
        return defer.reject(err or new Error(res.text))
      defer.resolve(JSON.parse(res.text))
  return defer.promise


exports.setStoryState = (storyId, state) ->
  console.log 'PT setStoryState', storyId, state
  getProjects()
    .then (projects) ->
      console.log 'projects', (id for {id} in projects)
      qStories = _.map projects, (project) ->
        defer = Q.defer()
        sa
          .put("#{ROOT_URL}/projects/#{project.id}/stories/#{storyId}")
          .set('X-TrackerToken', process.env.PT_TOKEN)
          .send({current_state: state})
          .end (err, res) ->
            if err or not res.ok
              return Q.reject(err or new Error(res.text))
            Q.resolve(JSON.parse(res.text))
        defer.promise
      # Get all promises regardless of their resolution state.
      Q.allSettled(qStories)

    .then (settledPromises) ->
      console.log 'settled promises', settledPromises
      # Let's see if we have any resolved promises.
      p = _.find settledPromises, state: "fulfilled"
      if not p
        console.log "No relevant story found..."
        return Q.rejected(new Error("Could not find story #{story_id}."))
      # Yay, updating story state succeeded.
      console.log "Story state updated!"
      return Q("done")

    .fail (err) ->
      console.error "setStoryState error", err
      Q.reject(err)
