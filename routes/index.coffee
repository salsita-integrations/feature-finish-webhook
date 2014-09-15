express = require('express')
router = express.Router()
Q = require('q')
_ = require('lodash')
debug = require('debug')('feature_finish')
pt = require('../models/pivotal')


Q.longStackSupport = true


router.get '/', (req, res) ->
  res.render('index', { title: 'Express' })


# Check commit message for PT story id.
# We're trying to find a line with 'story-id: <PT-story-id>'.
#
# Returns story id string or `null`.
parseCommitMessage = (commit) ->
  console.log 'parsing commit message', commit.message
  matches = _.filter commit.message.split('\n'), (line) ->
    line.toLowerCase().indexOf('story-id') >= 0
  return null unless matches.length > 0
  storyId = _.last(matches).split(':')[1]
  return storyId.trim()


# GitHub push webhook. The idea id to detect merges into develop
router.post '/finish', (req, res) ->
  # We're only interested in pushes on `develop`.
  return unless (req.body.ref == "refs/heads/develop")

  debug "body", req.body
  debug 'commits: ', JSON.stringify req.body.commits, null, 2

  commits = req.body.commits
  console.log 'commits', commits.length

  storyIds = _.uniq _.compact (parseCommitMessage(commit) for commit in commits)
  console.log "Found story ids to finish: ", storyIds

  Q.allSettled((pt.setStoryState(id, 'finished') for id in storyIds))

    .then (promises) ->
      rejects = _.filter(promises, state: 'rejected')
      if rejects.length > 0
        ids = (r.reason?.id for r in rejects)
        return res.send(500, "stories #{ids} could not have been finished.")
      else
        return res.send("All stories updated successfully.")

    .fail (err) ->
      console.error "error", err
      res.send 500, err

    .done()


module.exports = router
