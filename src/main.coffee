app = require 'app'                       # Module to control application life.
BrowserWindow = require 'browser-window'  # Module to create native browser window.
Menu = require 'menu'

# Report crashes to our server.
require('crash-reporter').start()

# Keep a global reference of the window object, if you don't, the window will
# be closed automatically when the javascript object is GCed.
mainWindow = null

# Quit when all windows are closed.
app.on 'window-all-closed', ->
  app.quit()

# This method will be called when atom-shell has done everything
# initialization and ready for creating browser windows.
app.on 'ready', ->
  process.env.PATH = "/usr/local/bin:/usr/bin:/bin"
  # Create the browser window.
  mainWindow = new BrowserWindow({width: 1024, height: 1400})
  # app.mainWindow = mainWindow

  # and load the index.html of the app.
  mainWindow.loadUrl('file://' + __dirname + '/views/index.html')
  mainWindow.openDevTools()

  #/ Emitted when the window is closed.
  mainWindow.on 'closed', ->
    # Dereference the window object, usually you would store windows
    # in an array if your app supports multi windows, this is the time
    # when you should delete the corresponding element.
    mainWindow = null

  menu_tmpl = [
    label: 'Maid'
    submenu: [
      label: 'Quit'
      accelerator: 'Command+Q'
      click: ->
        app.quit()
    ]
  ,
    label: 'Window'
    submenu: [
      label: 'Reload'
      accelerator: 'F9'
      click: ->
        mainWindow.reload()
    ,
      label: 'Toggle DevTools'
      accelerator: 'Alt+Command+I'
      click: ->
        mainWindow.toggleDevTools()
    ,
      label: 'Close'
      accelerator: 'Command+W'
      click: ->
        mainWindow.close()
    ]
  ]
  menu = Menu.buildFromTemplate(menu_tmpl)
  Menu.setApplicationMenu(menu)

ipc = require 'ipc'
webdriver = require('selenium-webdriver')
By = webdriver.By
till = webdriver.until
chrome = require('selenium-webdriver/chrome')
fs = require 'fs'
http = require 'http'
request = require 'request'
driver = null

log = (str) ->
  mainWindow.webContents.send('log', str)

click_loc = (locator, i) ->
  driver.wait(till.elementLocated(locator), 5000, "click timeout").then ->
    driver.findElements(locator).then (elems) ->
      if elems.length > i
        elems[i].click()
      else
        log "#{elems.length} #{i}"

click_xpath = (elem_path, i) ->
  click_loc(By.xpath(elem_path), i)

click = (selector, i) ->
  click_loc(By.css(selector), i)

click_child = (elem, selector) ->
  elem.findElement(By.css(selector)).then (child) ->
    child.click()

find_text = (selector) ->
  driver.wait(till.elementLocated(By.css(selector)), 5000, "find_text").then ->
    elem = driver.findElement(By.css(selector))
    elem.getText()

get_text = (selector) ->
  driver.wait(till.elementLocated(By.css(selector)), 5000, "get_text").then ->
    elem = driver.findElement(By.css(selector))
    elem.getText()

find_text_xpath = (path) ->
  driver.wait(till.elementLocated(By.xpath(path)), 5000, "timeout").then ->
    elem = driver.findElement(By.xpath(path))
    elem.getText()

find_child_text = (elem, selector) ->
  elem.findElement(By.css(selector)).then (child) ->
    child.getText()

find_elements = (selector, selector2) ->
  driver.wait(till.elementLocated(By.css(selector)), 3000, "find_elements timeout").then ->
    driver.findElements(By.css(selector))
  .thenCatch ->
    driver.findElements(By.css(selector2))

item_per_page = 0

find_elem = (selector, i) ->
  driver.wait(till.elementLocated(By.css(selector)), 5000, "find_elem timeout").then ->
    driver.findElements(By.css(selector)).then (elems) ->
      if elems[i]
        driver.executeScript("arguments[0].scrollIntoView(true);", elems[i])
        elems[i]
      else
        if item_per_page == 0
          item_per_page = i
        find_elem(selector, i % item_per_page)

parse_movie = (text, studio) ->
  movie =
    summary: ""
    image_url: ""
    full_title: ""         # studio - title
    studio: ""
    title: ""
    year: ""

  text = text.replace(/[\._]/g, ' ')
  m = text.match(/\b(\d\d\d\d)\b/)
  if m
    movie.year = m[0]
  r = text.replace(/dvdrip|\d\d\d\d/gi, '')
          .replace(/\ ntsc/i, '')
          .replace(/\ +$/, '')
          .replace(/\ 1$/, '')
          .replace(/\ +-$/, '')
  if m = r.match(RegExp("^(#{studio}) +- +(.+)", 'i'))
    r = m[1] + " - " + m[2]
    movie.title = m[2]
  else
    m = r.match(RegExp("^(#{studio}) (.+)$", 'i'))
    if m
      r = m[1] + " - " + m[2]
      movie.title = m[2]
  movie.full_title = r
  movie

remove_extra = (str) ->
  str.replace(/\ - extras/i, '')
    .replace(/\ - extra clips/i, '')
    .replace(/\ - extra clip/i, '')
    .replace(/\ - making ntsc/i, '')
    .replace(/\ - compilation/i, '')
    .replace(/\ - leg language/i, '')
    .replace(/\ - side b - \w+/i, '')
    .replace(/\ - side b/i, '')

remove_extra2 = (str) ->
  remove_extra(str).replace(/the +/i, '')

search_term = (movie, site) ->
  title = remove_extra(movie.full_title)
  "#{title} #{movie.year} site:#{site}"

search_term_without_year = (movie, site) ->
  title = remove_extra(movie.full_title)
  "#{title} site:#{site}"

match_term1 = (movie) ->
  remove_extra(movie.title) + " dvd"

match_term2 = (movie) ->
  remove_extra2(movie.title) + " dvd"

match_term3 = (movie) ->
  remove_extra(movie.title) + ".+dvd"

send_enter = (elem_path, str) ->
  driver.wait(till.elementLocated(By.xpath(elem_path)), 5000)
  driver.findElement(By.xpath(elem_path))
    .sendKeys(str, webdriver.Key.RETURN)

windows = []

save_windows = ->
  driver.getAllWindowHandles().then (ws) ->
    windows = ws

switch_to = ->
  driver.getAllWindowHandles().then (ws) ->
    for w in ws
      if w not in windows
        windows.push(w)
        driver.switchTo().window(w)

switch_to_first_window = ->
  driver.switchTo().window(windows[0])

open_tab = ->
  driver.executeScript("window.open()")
  switch_to()

search = (text) ->
  open_tab().then ->
    driver.get("https://google.com").then ->
      send_enter "//input[@name='q']", text

move_mouse = (selector) ->
  driver.wait(till.elementLocated(By.css(selector)), 5000).then ->
    driver.findElement(By.css(selector), 5000).then (elem) ->
      driver.actions().mouseMove(elem).perform()

find_image = (selector) ->
  driver.wait(till.elementLocated(By.css(selector)), 5000).then ->
    driver.findElement(By.css(selector))

find_image_or = (selector1, selector2) ->
  driver.wait(till.elementLocated(By.css(selector1)), 3000).then ->
    driver.findElement(By.css(selector1))
  , ->
    driver.wait(till.elementLocated(By.css(selector2)), 1000).then ->
      driver.findElement(By.css(selector2))

save_image = (selector) ->
  driver.wait(till.elementLocated(By.css(selector)), 5000).then ->
    driver.findElement(By.css(selector)).then (elem) ->
      elem.getAttribute('src').then (src) ->
        movie.image_url = src
        # file = fs.createWriteStream("/Users/apple/Downloads/image.jpg")
        # http.get(src, (response) ->
        #   response.pipe(file))
        find_text("td.descr > p").then (text) ->
          movie.summary = text

check_url = (url, then_callback) ->
  request url, (error, response, body) ->
    if !error && !body.match(/removed/)
      then_callback()

get_info_from_adult_film_database = (movie) ->
  find_image_or(
    "body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(1) > table > tbody > tr:nth-child(1) > td > img",
    "body > table > tbody > tr > td > table > tbody > tr > td > table > tbody > tr > td > span > a > img").then (elem) ->
    elem.getAttribute('src').then (src) ->
      hi_src = src.replace(/\/200\//, '/350/')
      movie.image_url = src
      check_url hi_src, ->
        movie.image_url = hi_src

      # find_text_xpath("//table/tbody/tr/td/table/tbody/tr/td/table/tbody/tr/td/br/..").then (text) ->
      find_text_xpath("/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[6]/td").then (text) ->
        movie.summary = text
      find_text_xpath("/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[3]/td[2]").then (text) ->
        if text.match(/\d\d\d\d/)
          movie.year = text

get_info_from_andrew_blake_com = (movie) ->
  find_image("#product_thumbnail").then (elem) ->
    elem.getAttribute('src').then (src) ->
      movie.image_url = src
      find_text_xpath("//*[@id='center-main']/div[2]/div/div/div[2]/form/table[1]/tbody/tr/td/p[1]").then (text) ->
        movie.summary = text

close_window = ->
  driver.close()
  windows.pop()
  driver.switchTo().window(windows[windows.length - 1])

close_until = ->
  close_window().then ->
    if windows.length == 1
      return
    else
      close_until()

send_keys = (selector, str) ->
  driver.wait(till.elementLocated(By.css(selector)), 5000).then ->
    driver.findElement(By.css(selector)).then (elem) ->
      driver.wait(till.elementIsVisible(elem), 5000).then ->
        elem.clear().then ->
          elem.sendKeys(str)

click_matching = (str, elements, i) ->
  elements[i].getText().then (text) ->
    if text.match(RegExp(str, 'i'))
      elements[i].click()
    else
      if i + 1 < elements.length
        click_matching(str, elements, i + 1)

find_candidate_rec = (str, elements, candi) ->
  elem = elements.shift()
  if elem
    elem.getText().then (text) ->
      if text.match(RegExp(str, 'i'))
        if candi.length > text.length
          candi.length = text.length
          candi.elem = elem
      find_candidate_rec(str, elements, candi)
  else
    candi.elem

find_candidate = (str, elements) ->
  candi = { length: 99999, elem: null }
  find_candidate_rec(str, elements, candi)

match_variation = (text, str) ->
  if text.match(RegExp(str, 'i')) && !text.match(RegExp("#{str} [2] ", 'i'))
    true
  else
    str2 = str.replace(/\ and /i, ' & ')
    if text.match(RegExp(str2, 'i'))
      true
    else
      str3 = str.replace(/\ 2 /i, ' ii ')
      if text.match(RegExp(str3, 'i'))
        true
      else
        false

find_first = (str, elements) ->
  elem = elements.shift()
  if elem
    elem.getText().then (text) ->
      if match_variation(text, str)
        elem
      else
        find_first(str, elements)
  else
    webdriver.promise.fulfilled(null)

enter_data = (movie, entry) ->
  driver.actions().mouseMove(entry).perform().then ->
    click_child(entry, "button.edit-btn").then ->
      send_keys("input#lockable-title", movie.full_title).then ->
        if movie.year && movie.year.length > 0
          send_keys("input#lockable-year", movie.year)
        send_keys("textarea#lockable-summary", movie.summary).then ->
          click("a.btn-gray.change-pane-btn.poster-btn", 0).then ->
            click("a.upload-url-btn", 0).then ->
              send_keys("input[name=url]", movie.image_url).then ->
                click("a.submit-url-btn", 0).then ->
                  click("button.save-btn.btn.btn-primary.btn-loading", 0)

try_andrew_blake_com = ->
  click("ol > div.srg > li.g > div.rc > h3.r > a", 0).then ->
    switch_to().then ->
      save_image("div.product-details > div.image > div.image-box > img#product_thumbnail").then ->
        close_window().then ->
          close_window().then ->
            enter_data()

find_and_click = (movie, elems) ->
  find_first(match_term1(movie), elems.slice(0)).then (elem) ->
    if elem
      elem
    else
      find_first(match_term2(movie), elems.slice(0)).then (elem) ->
        if elem
          elem
        else
          find_first(match_term3(movie), elems.slice(0))

search_and_click = (movie, site) ->
  search search_term(movie, site)
  find_elements("ol > div.srg > li.g > div.rc > h3.r > a",
                "#rso > li > div > h3 > a").then (elems) ->
    find_and_click(movie, elems).then (elem) ->
      if elem
        elem.click().then ->
          switch_to()
      else
        search search_term_without_year(movie, site)
        find_elements("ol > div.srg > li.g > div.rc > h3.r > a",
                      "#rso > li > div > h3 > a").then (elems) ->
          find_and_click(movie, elems).then (elem) ->
            if elem
              elem.click().then ->
                switch_to()
            else
              webdriver.promise.rejected()

scrape_andrew_blake = (movie, entry) ->
  search_and_click(movie, 'adultfilmdatabase.com').then ->
    get_info_from_adult_film_database(movie)
  , ->
    search_and_click(movie, 'store.andrewblake.com').then ->
      get_info_from_andrew_blake_com(movie)
  .then ->
    close_until().then ->
      enter_data(movie, entry)

scrape_x_art = (movie, entry) ->
  search_and_click(movie, '')

scrape_james_dean = (movie, entry) ->
  search_and_click(movie, '')

scrape_file_name = (entry) ->
  driver.actions().mouseMove(entry).perform()
  click_child(entry, "button.more-btn")
  click("div.media-actions-dropdown > ul.dropdown-menu > li > a.info-btn", 0)
  driver.sleep(1000)
  get_text("div.files > ul.media-info-file-list.well > li").then (text) ->
    log text
    log 'hello'

scrape_i = 0

scrape = ->
  find_elem("a.media-list-inner-item.show-actions", scrape_i).then (entry) ->
    driver.sleep(100).then ->
      entry.findElement(By.css("p.media-summary")).then (elem) ->
        elem.getText().then (text) ->
          if text
            scrape_i += 1
            scrape()
          else
            find_child_text(entry, "span.media-title").then (text) ->
              if text.match(/andrew.blake/i)
                movie = parse_movie(text, "andrew blake")
                # movie.full_title = to_full_title(text, "andrew blake")
                # movie.title = to_title(movie.full_title, "andrew blake")
                scrape_andrew_blake(movie, entry)
                scrape_i += 1
              else if text.match(/x-art/i)
                movie = parse_movie(text, "x-art")
                scrape_x_art(movie, entry)
              else if text.match(/james dean/i)
                movie = parse_movie(text, "james dean")
                scrape_james_dean(movie, entry)
              else
                scrape_file_name(entry)

ipc.on 'scrape', (event, arg) ->
  if !driver
    options = new chrome.Options()
        .addArguments("user-data-dir=/Users/apple/hobby/atomaid/Chrome")

    driver = new webdriver.Builder()
        .forBrowser('chrome')
        .setChromeOptions(options)
        .build()

    driver.get('http://127.0.0.1:32400/web/index.html')
    save_windows()    # initial window
    click_xpath "//span[text() = 'porn']", 0
    scrape_i = 0

  scrape()
