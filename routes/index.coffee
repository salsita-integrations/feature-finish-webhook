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

  debug 'commits: ', JSON.stringify req.body.commits, null, 2

  getMergedStoryId = (mergeCommit) ->
    # Get parent commits of `mergeCommit`.
    qParentCommits = _.map mergeCommit.parents, (parent) ->
      qGetCommit({user: user, repo: repo, sha: parent.sha})

    Q.all(qParentCommits).then (parentCommits) ->
      console.log 'parent commits', (sha for {sha} in parentCommits)
      # Parse commit messages to get PT story id from `story-id:` lines.
      storyIds = _.map parentCommits, (c) -> parseCommitMessage(c)
      debug 'story ids for merge', storyIds
      # Use `compact` to remove nulls (merge commit has no story id in the
      # commit message).
      return _.compact(storyIds)[0]

  # Get the GitHub API client.
  ghclient = req.app.get 'github_client'
  gdapi = ghclient.getGitdataApi()
  # Construct promises-aware wrapper.
  qGetCommit = Q.nbind gdapi.getCommit, gdapi
  [user, repo] = req.body.repository.full_name.split '/'

  # Get commit details from GH (to get parents)
  commits = _.map req.body.commits, (commit) ->
    qGetCommit({user: user, repo: repo, sha: commit.id})

  Q.all(commits)

    .then (commits) ->
      console.log 'commits', commits.length

      # Get merge commits.
      merges = _.filter commits, ({parents}) -> parents.length > 1
      console.log 'merges', merges.length

      qStoryIds = (getMergedStoryId(merge) for merge in merges)
      return Q.all(qStoryIds)

    .then (ids) ->
      console.log 'story ids', ids
      # Filter out `undefined` values (happens when no parent commit 
      # in the merge has `story-id` in the commit msg.
      ids = _.compact ids
      Q.all _.map ids, (id) -> pt.setStoryState(id, 'finished')

    .then ->
      res.send 'ok'

    .fail (err) ->
      console.error "error", err
      res.send 500, err

    .done()


module.exports = router
