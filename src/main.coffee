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
driver = null

log = (str) ->
  mainWindow.webContents.send('log', str)

click = (elem_path, i, cb) ->
  driver.wait(till.elementLocated(By.xpath(elem_path)), 5000)
  driver.findElements(By.xpath(elem_path)).then (elems) ->
    if elems.length > i
      elems[i].click().then(cb)
    else
      log "#{elems.length} #{i}"

find_text = (elem_path) ->
  driver.wait(till.elementLocated(By.xpath(elem_path)), 5000, "timeout").then ->
    elem = driver.findElement(By.xpath(elem_path))
    elem.getText()

scrape = (i) ->
  click "//div[@class='media-poster']", i, ->
    find_text("//p[@class='item-summary metadata-summary']").then (text) ->
      driver.navigate().back().then ->
        driver.sleep(1000).then ->
          scrape(i + 1)
    , (r) ->
      find_text("//h1[@class='item-title']").then (text) ->
        log 'here '+text


ipc.on 'scrape', (event, arg) ->
  options = new chrome.Options()
      .addArguments("user-data-dir=/Users/apple/hobby/atomaid/Chrome")

  driver = new webdriver.Builder()
      .forBrowser('chrome')
      .setChromeOptions(options)
      .build();

  driver.get('http://127.0.0.1:32400/web/index.html')
  click "//span[text() = 'porn']", 0, ->
    scrape(0)
