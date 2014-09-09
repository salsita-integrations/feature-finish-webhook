express = require('express')
router = express.Router()
Q = require('q')
_ = require('lodash')
debug = require('debug')('feature_finish')


Q.longStackSupport = true


router.get '/', (req, res) ->
  res.render('index', { title: 'Express' })


parseCommitMessage = (commit) ->
  matches = _.filter commit.message.split('\n'), (line) ->
    line.toLowerCase().indexOf('story-id') >= 0
  return null unless matches.length > 0
  storyId = _.last(matches).split(':')[1]
  return storyId.trim()


router.post '/finish', (req, res) ->
  ghclient = req.app.get 'github_client'
  debug 'commits: ', JSON.stringify req.body.commits, null, 2

  gdapi = ghclient.getGitdataApi()
  qGetCommit = Q.nbind gdapi.getCommit, gdapi
  [user, repo] = req.body.repository.full_name.split '/'

  commits = _.map req.body.commits, (commit) ->
    qGetCommit({user: user, repo: repo, sha: commit.id})


  getMergedStoryId = (mergeComit) ->
    qParentCommits = _.map mergeComit.parents, (parent) ->
      qGetCommit({user: user, repo: repo, sha: parent.sha})

    Q.all(qParentCommits).then (parentCommits) ->
      debug 'parent commits', parentCommits
      storyIds = _.map parentCommits, (c) -> parseCommitMessage(c)
      debug 'story ids for merge', storyIds
      return _.compact(storyIds)[0]


  Q.all(commits)

    .then (commits) ->
      debug.log 'commits', commits.length

      merges = _.filter commits, ({parents}) -> parents.length > 1
      debug.log 'merges', merges

      qStoryIds = (getMergedStoryId(merge) for merge in merges)
      return Q.all(qStoryIds)

    .then (ids) ->
      console.log 'story ids', ids
      res.send 'ok'

    .fail (err) ->
      console.error "error", err
      res.send 500, err

    .done()


module.exports = router
