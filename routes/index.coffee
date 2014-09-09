express = require('express')
router = express.Router()
Q = require('q')
_ = require('lodash')


Q.longStackSupport = true


router.get '/', (req, res) ->
  res.render('index', { title: 'Express' })


parseCommitMessage = (commit) ->
  matches = _.filter commit.message.split('\n'), (line) ->
    line.toLowerCase().indexOf('story-id') >= 0
  return null unless matches.length > 0
  storyId = _.last(matches).split(':')[1]
  return storyId


router.post '/finish', (req, res) ->
  console.log 'POST to /finish'

  ghclient = req.app.get 'github_client'
  console.log 'commits: ', JSON.stringify req.body.commits, null, 2

  gdapi = ghclient.getGitdataApi()
  qGetCommit = Q.nbind gdapi.getCommit, gdapi
  [user, repo] = req.body.repository.full_name.split '/'

  commits = _.map req.body.commits, (commit) ->
    qGetCommit({user: user, repo: repo, sha: commit.id})


  getMergedStoryId = (mergeComit) ->
    qParentCommits = _.map mergeComit.parents, (parent) ->
      qGetCommit({user: user, repo: repo, sha: parent.sha})

    Q.all(qParentCommits).then (parentCommits) ->
      storyIds = _.map parentCommits, parseCommitMessage
      return _.compact(storyIds)[0]


  Q.all(commits)

    .then (commits) ->
      console.log 'commits', commits.length

      merges = _.filter commits, ({parents}) -> parents.length > 1
      console.log 'merges', merges

      qStoryIds = (getMergedStoryId(merge) for merge in merges)
      return Q.all(qStoryIds)

    .then (ids) ->
      console.log 'story ids', ids
      res.send 'ok'

    .fail (err) ->
      console.log "error", err
      res.send 500, err

    .done()


module.exports = router
