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
  driver.wait(till.elementLocated(By.css(selector)), 5000, "timeout").then ->
    elem = driver.findElement(By.css(selector))
    elem.getText()

find_text_xpath = (path) ->
  driver.wait(till.elementLocated(By.xpath(path)), 5000, "timeout").then ->
    elem = driver.findElement(By.xpath(path))
    elem.getText()

find_child_text = (elem, selector) ->
  elem.findElement(By.css(selector)).then (child) ->
    child.getText()

find_elements = (selector) ->
  driver.wait(till.elementLocated(By.css(selector)), 5000, "find_elements timeout").then ->
    driver.findElements(By.css(selector))

find_elem = (selector, i) ->
  driver.wait(till.elementLocated(By.css(selector)), 5000, "find_elem timeout").then ->
    driver.findElements(By.css(selector)).then (elems) ->
      driver.executeScript("arguments[0].scrollIntoView(true);", elems[i])
      elems[i]

movie =
  summary: ""
  image_url: ""
  full_title: ""         # studio - title
  studio: ""
  title: ""
  year: ""

to_full_title = (text, studio) ->
  text = text.replace(/[\._]/g, ' ')
  m = text.match(/\b(\d\d\d\d)\b/)
  if m
    movie.year = m[0]
  r = text.replace(/dvdrip|\d\d\d\d/gi, '')
          .replace(/[ ]+$/, '')
  if m = r.match(RegExp("^(#{studio}) +- +(.+)", 'i'))
    r = m[1] + " - " + m[2]
  else
    m = r.match(RegExp("^(#{studio}) (.+)$", 'i'))
    if m
      r = m[1] + " - " + m[2]
  r

to_title = (full_title, studio) ->
  full_title.replace(RegExp("#{studio}( +- +| +)", 'i'), '')

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
      new webdriver.ActionSequence(driver).mouseMove(elem).perform()

find_image_or = (selector1, selector2) ->
  driver.wait(till.elementLocated(By.css(selector1)), 2000).then ->
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

save_image_adult_film_database = ->
  # move_mouse("tbody > tr > td > span > a > img").then ->
  #   selector = "div.module.yui-overlay.yui-tt > div.bd > div > img"
  find_image_or("tbody > tr > td > span > a > img", "body > table > tbody > tr > td > table > tbody > tr > td > table > tbody > tr > td > img").then (elem) ->
    elem.getAttribute('src').then (src) ->
      movie.image_url = src
      find_text_xpath("//table/tbody/tr/td/table/tbody/tr/td/table/tbody/tr/td/br/..").then (text) ->
        movie.summary = text
      find_text_xpath("/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[3]/td[2]").then (text) ->
        if text.match(/\d\d\d\d/)
          movie.year = text

close_window = ->
  driver.close()
  windows.pop()
  driver.switchTo().window(windows[windows.length - 1])

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
      click_matching(elements, i + 1)

enter_data = (entry) ->
  new webdriver.ActionSequence(driver).mouseMove(entry).perform().then ->
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

try_adult_film_database_com = (entry) ->
  search movie.full_title + ' site:adultfilmdatabase.com'
  find_elements("ol > div.srg > li.g > div.rc > h3.r > a").then (elems) ->
    click_matching("#{movie.title}", elems, 0).then ->
      switch_to().then ->
        save_image_adult_film_database().then ->
          close_window().then ->
            close_window().then ->
              enter_data(entry)

scrape = (i) ->
  find_elem("a.media-list-inner-item.show-actions", i).then (entry) ->
    entry.findElement(By.css("p.media-summary")).then (elem) ->
      elem.getText().then (text) ->
        if text
          scrape(i + 1)
        else
          find_child_text(entry, "span.media-title").then (text) ->
            if text.match(/andrew.blake/i)
              movie.full_title = to_full_title(text, "andrew blake")
              movie.title = to_title(movie.full_title, "andrew blake")
              try_adult_film_database_com(entry)
              # search movie.full_title + ' site:store.andrewblake.com'
              # find_text("ol > div.srg > li.g > div.rc > h3.r > a").then (text) ->
              #   if text.match(movie.title)
              #     try_andrew_blake_com()
              #   else
              #     try_adult_film_database_com()
    # find_text("p.media-summary").then (text) ->
    #   if text && text.length > 0
    #     driver.navigate().back().then ->
    #       driver.sleep(1000).then ->
    #         scrape(i + 1)
    #   else
    #     find_text("h1.item-title").then (text) ->
    #       if text.match(/andrew.blake/i)
    #         movie.full_title = to_full_title(text)
    #         movie.title = to_title(movie.full_title, "andrew blake")
    #         search movie.full_title + ' site:store.andrewblake.com'
    #         find_text("ol > div.srg > li.g > div.rc > h3.r > a").then (text) ->
    #           if text.match(movie.title)
    #             try_andrew_blake_com()
    #           else
    #             try_adult_film_database_com()

ipc.on 'scrape', (event, arg) ->
  options = new chrome.Options()
      .addArguments("user-data-dir=/Users/apple/hobby/atomaid/Chrome")

  driver = new webdriver.Builder()
      .forBrowser('chrome')
      .setChromeOptions(options)
      .build();

  driver.get('http://127.0.0.1:32400/web/index.html')
  save_windows()    # initial window
  click_xpath "//span[text() = 'porn']", 0
  scrape(0)
