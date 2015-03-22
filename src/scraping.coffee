scraper = angular.module('scraper', [])

remote = require 'remote'
# webdriverio = remote.require 'webdriverio'
ipc = require 'ipc'
webdriver = remote.require('selenium-webdriver')
# SeleniumServer = remote.require('selenium-webdriver/remote').SeleniumServer
xpath = webdriver.By.xpath
timeout = null
driver = null

find_elements = (elem_path, count, f) ->
  elements = driver.findElements(xpath(elem_path)).then (elements) ->
    if elements.length > 0
      f(elements)
    else
      if count > 0
        console.log "retry #{count}"
        timeout ->
          find_elements elem_path, count - 1, f
        , 500
      else
        f()

find_element = (elem_path, count, f) ->
  find_elements elem_path, count, (elements) ->
    if elements
      f(elements[0])
    else
      f()

send_enter = (elem_path, str, f) ->
  find_element elem_path, 1000, (elem) ->
    elem.sendKeys(str, webdriver.Key.RETURN).then f

open_tab = (url, f) ->
  driver.executeScript("window.open()")
  driver.getWindowHandle().then (cur_win) ->
    driver.getAllWindowHandles().then (windows) ->
      for w in windows
        if w != cur_win
          driver.switchTo().window(w).then ->
            driver.get(url).then(f)

find_text = (elem_path, f) ->
  find_element elem_path, 2, (elem) ->
    if elem
      elem.getInnerHtml().then (text) ->
        f(text)
    else
      f()

search = (text) ->
  open_tab "https://google.com", ->
    send_enter "//input[@name='q']", text, ->

contains = (text, str) ->
  text.indexOf(str) >= 0

to_search = (text) ->
  text.replace(/[\._]/g, ' ')
      .replace(/dvdrip|\d\d\d\d/gi, '')

scrape = (movie_num) ->
  console.log "scrape #{movie_num}"
  click "//div[@class='media-poster']", movie_num, ->
    find_text "//p[@class='item-summary metadata-summary']", (text) ->
      console.log "summary " + text
      if text && text.length > 0
        driver.navigate().back()
        scrape(movie_num + 1)
      else
        find_text "//h1[@class='item-title']", (text) ->
          if contains(text, 'andrew') && contains(text, 'blake')
            search to_search(text) + ' site:store.andrewblake.com'

ipc.on('log', (str) ->
  console.log str
)

scraper.controller 'ScrapingCtrl', ['$scope', '$timeout', ($scope, $timeout) ->
  timeout = $timeout

  $scope.scraping = ->
    ipc.send('scrape', 'start')

    # driver.quit();

  $scope.end = ->
    webdriverio.end()

  # $timeout ->
  #   $scope.scraping()
  # , 1000
  $scope.scraping()
]
