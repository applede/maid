import app from 'app';
import BrowserWindow from 'browser-window';
import Menu from 'menu';
import {} from './scrape';

// Report crashes to our server.
require('crash-reporter').start();

// Keep a global reference of the window object, if you don't, the window will
// be closed automatically when the javascript object is GCed.
var mainWindow = null;

// Quit when all windows are closed.
app.on('window-all-closed', function() {
  app.quit();
});

// This method will be called when Electron has done everything
// initialization and ready for creating browser windows.
app.on('ready', function() {
  process.env.PATH = '/usr/local/bin:/usr/bin:/bin';

  // Create the browser window.
  mainWindow = new BrowserWindow({width: 1024, height: 1400});

  // and load the index.html of the app.
  mainWindow.loadUrl(`file://${__dirname}/index.html`);
  mainWindow.openDevTools();

  // Emitted when the window is closed.
  mainWindow.on('closed', function() {
    // Dereference the window object, usually you would store windows
    // in an array if your app supports multi windows, this is the time
    // when you should delete the corresponding element.
    mainWindow = null;
  });

  var menu_tmpl = [
    {
      label: 'Maid',
      submenu: [
        {
          label: 'Quit',
          accelerator: 'Command+Q',
          click: () => { app.quit(); }
        }
      ]
    },
    {
      label: 'Window',
      submenu: [
        {
          label: 'Reload',
          accelerator: 'F9',
          click: () => { mainWindow.reload(); }
        }
      ]
    }
  ];
  let menu = Menu.buildFromTemplate(menu_tmpl);
  Menu.setApplicationMenu(menu);
});
