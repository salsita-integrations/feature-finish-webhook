express = require('express')
router = express.Router()


router.get '/', (req, res) ->
  res.render('index', { title: 'Express' })


router.post '/finish', (req, res) ->
  console.log 'POST to /finish'
  console.log req
  res.send 'ok'


module.exports = router
