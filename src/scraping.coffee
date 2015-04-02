scraper = angular.module('scraper', [])

ipc = require 'ipc'

ipc.on('log', (str) ->
  console.log str
)

scraper.controller 'ScrapingCtrl', ['$scope', '$timeout', ($scope, $timeout) ->
  $scope.scraping = ->
    ipc.send('scrape')
]
