express = require('express')
router = express.Router()
Q = require('q')
_ = require('lodash')


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


  Q.all(commits)

    .then (commits) ->
      console.log 'commits', commits.length
      merges = _.filter commits, ({parents}) -> parents.length > 1
      console.log 'merges', merges
      parent_tuples = _.map merges, (merge) ->
        _.map commit.parents, (parent) ->
          qGetCommit({user: user, repo: repo, sha: merge.sha})
      return Q.all(parent_tuples)

    .then (tuples) ->
      console.log 'tuples', tuples
      story_finish_commits = _.filter tuples, (tuple) ->
        _.filter tuple, parseCommitMessage
      console.log 'story finish commits', story_finish_commits
      stories_to_finish = (parseCommitMessage(c) for c in story_finish_commits)
      console.log 'stories to finish', stories_to_finish

      res.send 'ok'

    .fail (err) ->
      console.log "error", err
      res.send 500, err

    .done()


module.exports = router
