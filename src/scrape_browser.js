import React from 'react';
import ipc from 'ipc';
import {spawn_sync, join} from './util';

var Scrape = React.createClass({
  scrape() {
    spawn_sync('ruby', [join(__dirname, 'scrape.rb')]);
    // ipc.send('scrape');
    // var options = new chrome.Options()
    //     .addArguments('user-data-dir=/Users/apple/hobby/atomaid/Chrome');
    //
    // driver = new webdriver.Builder()
    //         .forBrowser('chrome')
    //         .setChromeOptions(options)
    //         .build();
    //
    // driver.sleep(3000);
    // driver.get('http://127.0.0.1:32400/web/index.html');
    // win_man = new WinMan(driver);
    // click_xpath('//span[text() = "porn"]');
    // // driver.quit();
    // scrape_i(0);
  },
  scrape_next() {
    ipc.send('scrape_next');
    // scrape_i(next_i);
  },
  render() {
    return (
      <div className='container'>
        <Button onClick={this.scrape}>Scrape</Button>
        <p></p>
        <Button onClick={this.scrape_next}>Next</Button>
      </div>
    );
  }
});

export default Scrape;
