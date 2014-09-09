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
      qStories = _.map projects, (project) ->
        defer = Q.defer()
        sa
          .put("#{ROOT_URL}/projects/#{project.id}/stories/#{storyId}")
          .set('X-TrackerToken', process.env.PT_TOKEN)
          .send({current_state: state})
          .end (err, res) ->
            if err or not res.ok
              return defer.reject(err or new Error(res.text))
            defer.resolve(JSON.parse(res.text))
        defer.promise
      # Get all promises regardless of their resolution state (so that we can
      # ignore errors).
      Q.allSettled(qStories)

    # We've pinged all the projects. Let's see if we succeeded.
    .then (settledPromises) ->
      console.log 'settled promises', settledPromises
      # Check if we have any resolved promises (i.e., update success).
      p = _.find settledPromises, state: "fulfilled"
      if not p
        console.log "No relevant story found..."
        return Q.rejected(new Error("Could not find story #{story_id}."))
      # Yay, updating story state succeeded!
      console.log "Story state updated!"
      return Q("done")

    .fail (err) ->
      console.error "setStoryState error", err
      Q.reject(err)
