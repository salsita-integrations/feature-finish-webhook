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
  octo = req.app.get 'octoclient'
  console.log 'octo', octo
  #console.log req.body
  #console.log '==================='
  console.log 'commits: ', JSON.stringify req.body.commits, null, 2

  repo = octo.Repository req.body.repository.full_name
  console.log "octo repo", octo
  qGetCommit = Q.nbind(octo.repo.get_commit, octo.repo)

  Q.all((qGetCommit(commit.id) for commit in req.body.commits))

    .then (commits) ->
      console.log 'commits', commits.length
      merges = _.filter commits, ({parents}) -> parents.length > 1
      console.log 'merges', merges
      parent_tuples = _.map merges, (commit) ->
        (qGetCommit(merge.sha) for parent in commit.parents)
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
