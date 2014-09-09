express = require('express')
router = express.Router()
Q = require('q')
_ = require('lodash')
debug = require('debug')('feature_finish')
pt = require('../models/pivotal')


Q.longStackSupport = true


router.get '/', (req, res) ->
  res.render('index', { title: 'Express' })


parseCommitMessage = (commit) ->
  console.log 'parsing commit message', commit.message
  matches = _.filter commit.message.split('\n'), (line) ->
    line.toLowerCase().indexOf('story-id') >= 0
  return null unless matches.length > 0
  storyId = _.last(matches).split(':')[1]
  return storyId.trim()


# GitHub push webhook. The idea id to detect merges into develop
router.post '/finish', (req, res) ->
  ghclient = req.app.get 'github_client'
  console.log 'req.body.ref', req.body.ref
  debug 'commits: ', JSON.stringify req.body.commits, null, 2

  getMergedStoryId = (mergeComit) ->
    qParentCommits = _.map mergeComit.parents, (parent) ->
      qGetCommit({user: user, repo: repo, sha: parent.sha})

    Q.all(qParentCommits).then (parentCommits) ->
      console.log 'parent commits', (sha for {sha} in parentCommits)
      storyIds = _.map parentCommits, (c) -> parseCommitMessage(c)
      debug 'story ids for merge', storyIds
      return _.compact(storyIds)[0]

  gdapi = ghclient.getGitdataApi()
  qGetCommit = Q.nbind gdapi.getCommit, gdapi
  [user, repo] = req.body.repository.full_name.split '/'

  # Get commit details from GH (to get parents)
  commits = _.map req.body.commits, (commit) ->
    qGetCommit({user: user, repo: repo, sha: commit.id})

  Q.all(commits)

    .then (commits) ->
      console.log 'commits', commits.length

      merges = _.filter commits, ({parents}) -> parents.length > 1
      console.log 'merges', (id for {id} in merges)

      qStoryIds = (getMergedStoryId(merge) for merge in merges)
      return Q.all(qStoryIds)

    .then (ids) ->
      console.log 'story ids', ids
      Q.all _.map ids, (id) -> pt.setStoryState(id, 'finished')

    .then ->
      res.send 'ok'

    .fail (err) ->
      console.error "error", err
      res.send 500, err

    .done()


module.exports = router
