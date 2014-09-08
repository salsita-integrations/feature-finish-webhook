express = require('express')
router = express.Router()


router.get '/', (req, res) ->
  res.render('index', { title: 'Express' })


router.post '/finish', (req, res) ->
  console.log 'POST to /finish'
  console.log req
  console.log '==================='
  console.log 'commits: ', JSON.stringify req.body.commits, null, 2
  res.send 'ok'


module.exports = router
