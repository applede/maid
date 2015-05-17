import {contains, last_of} from './util';

// window management
class WindowManager {
  constructor(driver) {
    this.driver = driver;
    this.windows = [];
    this.save_windows();
  }

  // save all window handles to global variable windows
  save_windows() {
    this.driver.getAllWindowHandles().then((ws) => {
      this.windows = ws;
    });
  }

  // switch to new window
  switch_to() {
    return this.driver.getAllWindowHandles().then((ws) => {
      console.log(ws);
      for (var w of ws) {
        if (!contains(this.windows, w)) {
          this.windows.push(w);
          return this.driver.switchTo().window(w);
        }
      }
    });
  }

  // open new tab
  open_tab() {
    this.driver.executeScript('window.open()');
    return this.switch_to();
  }

  // close tab
  close_tab() {
    console.log('close_tab');
    return this.driver.close().then(() => {
      this.windows.pop();
      return this.driver.switchTo().window(last_of(this.windows));
    });
  }

  // close all tabs except one
  close_tabs() {
    return this.close_tab().then(() => {
      if (this.windows.length === 1) {
        return;
      } else {
        this.close_tabs();
      }
    });
  }
}

export default WindowManager;
