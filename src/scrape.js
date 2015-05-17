import ipc from 'ipc';
import webdriver from 'selenium-webdriver';
// import remote from 'remote';
// var webdriver = remote.require('selenium-webdriver');

import chrome from 'selenium-webdriver/chrome';
import request from 'request';
import WinMan from './win_man';
import {basename, last_path, spawn_sync, rm} from './util';

var By = webdriver.By;
var until = webdriver.until;

// var browser;
var win_man;
var driver;
var next_i = 0;

function parse_movie(text, studio) {
  var movie = {
    summary: '',
    image_url: '',
    full_title: '',         // studio - title
    studio: '',
    title: '',
    year: ''
  };
  text = text.replace(/[\._]/g, ' ');
  var m = text.match(/\b(\d\d\d\d)\b/);
  if (m) {
    movie.year = m[0];
  }
  var r = text.replace(/dvdrip|\d\d\d\d/gi, '')
              .replace(/ ntsc/i, '')
              .replace(/ +$/, '')
              .replace(/ 1$/, '')
              .replace(/ +-$/, '');
  m = r.match(RegExp(`^(${studio}) +- +(.+)`, 'i'));
  if (m) {
    r = m[1] + ' - ' + m[2];
    movie.title = m[2];
  } else {
    m = r.match(RegExp(`^(${studio}) (.+)$`, 'i'));
    if (m) {
      r = m[1] + ' - ' + m[2];
      movie.title = m[2];
    }
  }
  movie.full_title = r;
  return movie;
}

// click ith element in elements specified by locator
function click_loc(locator, i) {
  return driver.wait(until.elementLocated(locator), 5000, 'click timeout').then(() => {
    return driver.findElements(locator).then((elems) => {
      if (elems.length > i) {
        return elems[i].click();
      } else {
        console.log('#{elems.length} #{i}');
      }
    });
  });
}

// click element by xpath
function click_xpath(elem_path) {
  return click_loc(By.xpath(elem_path), 0);
}

// click element by css selector
function click(selector) {
  return click_loc(By.css(selector), 0);
}

// click child of the elem specified by css selector
function click_child(elem, selector) {
  return elem.findElement(By.css(selector)).then((child) => {
    return child.click();
  });
}

// get text of element by css selector
function get_text(selector) {
  return driver.wait(until.elementLocated(By.css(selector)), 5000, 'get_text').then(() => {
    return driver.findElement(By.css(selector)).then((elem) => {
      return elem.getText();
    });
  });
}

// get text of child
function get_child_text(elem, selector) {
  return elem.findElement(By.css(selector)).then((child) => {
    return child.getText();
  });
}

// number of items shown in the page (Plex Media Server)
var item_per_page = 0;

// find ith item
function find_item(selector, i) {
  var loc = By.css(selector);
  return driver.wait(until.elementLocated(loc), 5000, 'find_item timeout').then(() => {
    return driver.findElements(loc).then((elems) => {
      if (elems[i]) {
        driver.executeScript('arguments[0].scrollIntoView(true);', elems[i]);
        return elems[i];
      } else {
        if (item_per_page === 0) {
          item_per_page = i;
        }
        return find_item(selector, i % item_per_page);
      }
    });
  });
}

// send str and enter key to elem
function send_enter(elem_path, str) {
  driver.wait(until.elementLocated(By.xpath(elem_path)), 5000).then(() => {
    return driver.findElement(By.xpath(elem_path)).sendKeys(str, webdriver.Key.RETURN);
  });
}

// search text at google
function search(text) {
  win_man.open_tab();
  driver.get('https://google.com');
  send_enter('//input[@name="q"]', text);
}

function remove_extra(str) {
  return str.replace(/ - extras/i, '')
            .replace(/ - extra clips/i, '')
            .replace(/ - extra clip/i, '')
            .replace(/ - making ntsc/i, '')
            .replace(/ - compilation/i, '')
            .replace(/ - leg language/i, '')
            .replace(/ - side b - \w+/i, '')
            .replace(/ - side b/i, '');
}

function remove_extra2(str) {
  return remove_extra(str).replace(/the +/i, '');
}

// search term for movie
function search_term(movie, site) {
  var title = remove_extra(movie.full_title);
  return `${title} ${movie.year} site:${site}`;
}

function search_term_without_year(movie, site) {
  var title = remove_extra(movie.full_title);
  return `${title} site:${site}`;
}

// first term to click in search result
function match_term1(movie) {
  return remove_extra(movie.title) + ' dvd';
}

function match_term2(movie) {
  return remove_extra2(movie.title) + ' dvd';
}

function match_term3(movie) {
  return remove_extra(movie.title) + '.+dvd';
}

// send keys to element
function send_keys(selector, str) {
  driver.wait(until.elementLocated(By.css(selector)), 5000).then(() => {
    driver.findElement(By.css(selector)).then((elem) => {
      driver.wait(until.elementIsVisible(elem), 5000).then(() => {
        elem.clear();
        elem.sendKeys(str);
      });
    });
  });
}

// enter data to movie item
function enter_data(entry, movie) {
  driver.sleep(500).then(() => {
    driver.actions().mouseMove(entry).perform().then(() => {
      click_child(entry, 'button.edit-btn').then(() => {
        driver.sleep(1000).then(() => {
          send_keys('body > div.edit-metadata-modal.modal.modal-lg.fade.pane-general.in > div > div > div.modal-body.modal-body-scroll.modal-body-with-panes > div.modal-body-pane.pane-region.dark-scrollbar > div > form > div:nth-child(1) > div > div > div > div > div.selectize-input.items.full.has-options.has-items > input[type="text"]', movie.full_title);
          if (movie.year && movie.year.length > 0) {
            send_keys('input#lockable-year', movie.year);
          }
          send_keys('textarea#lockable-summary', movie.summary);
          if (movie.image_url) {
            click('a.btn-gray.change-pane-btn.poster-btn');
            click('a.upload-url-btn');
            send_keys('input[name=url]', movie.image_url);
            click('a.submit-url-btn');
          }
          click('button.save-btn.btn.btn-primary.btn-loading');
        });
      });
    });
  });
}

// find elements or elements2
function find_elements_or(selector, selector2) {
  return driver.wait(until.elementLocated(By.css(selector)), 3000, 'find_elements_or timeout').then(() => {
    return driver.findElements(By.css(selector));
  }, () => {
    return driver.findElements(By.css(selector2));
  });
}

// match text to variations of str
function match_variation(text, str) {
  if (text.match(RegExp(str, 'i')) && !text.match(RegExp('#{str} [2] ', 'i'))) {
    return true;
  }
  var str2 = str.replace(/\ and /i, ' & ');
  if (text.match(RegExp(str2, 'i'))) {
    return true;
  }
  var str3 = str.replace(/\ 2 /i, ' ii ');
  if (text.match(RegExp(str3, 'i'))) {
    return true;
  }
  if (text.match(RegExp(str.replace(/[^-]+- /, '')))) {
    return true;
  }
  return false;
}

// find first element matching movie from elements
function find_first(str, elements, i) {
  if (i === undefined) {
    i = 0;
  }
  var elem = elements[i];
  if (elem) {
    return elem.getText().then((text) => {
      if (match_variation(text, str)) {
        return elem;
      } else {
        return find_first(str, elements, i + 1);
      }
    });
  } else {
    return webdriver.promise.fulfilled(null);
  }
}

// function find_link(movie, elems) {
//   return find_first(match_term1(movie), elems).then((elem) => {
//     if (elem)
//       return elem;
//     else {
//       return find_first(match_term2(movie), elems).then((elem) => {
//         if (elem)
//           return elem;
//         else
//           return find_first(match_term3(movie), elems);
//       });
//     }
//   });
// }

function try_search_and_click(movie, term) {
  search(term);
  return find_elements_or('ol > div.srg > li.g > div.rc > h3.r > a',
                          '#rso > li > div > h3 > a').then((elems) => {
    return find_first(movie.title, elems).then((elem) => {
      if (elem) {
        elem.click();
        win_man.switch_to();
        return true;
      } else {
        return false;
      }
    });
  });
}

// search and click proper link
function search_and_click(movie, site) {
  return try_search_and_click(movie, search_term(movie, site)).then((found) => {
    if (!found) {
      return try_search_and_click(movie, search_term_without_year(movie, site));
    }
  });
  // search(search_term(movie, site));
  // find_elements_or('ol > div.srg > li.g > div.rc > h3.r > a',
  //                  '#rso > li > div > h3 > a').then((elems) => {
  //   find_link(movie, elems).then((elem) => {
  //     if (elem) {
  //       elem.click().then(() => {
  //         win_man.switch_to();
  //       });
  //     } else {
  //       search(search_term_without_year(movie, site));
  //       find_link('ol > div.srg > li.g > div.rc > h3.r > a',
  //                        '#rso > li > div > h3 > a').then((elems) => {
  //         find_first(movie, elems).then((elem) => {
  //           if (elem) {
  //             elem.click().then(() => {
  //               win_man.switch_to();
  //             });
  //           } else {
  //             webdriver.promise.rejected();
  //           }
  //         });
  //       });
  //     }
  //   });
  // });
}

function find_image_or(selector1, selector2) {
  return driver.wait(until.elementLocated(By.css(selector1)), 3000).then(() => {
    return driver.findElement(By.css(selector1));
  }, () => {
    return driver.wait(until.elementLocated(By.css(selector2)), 1000).then(() => {
      return driver.findElement(By.css(selector2));
    });
  });
}

function check_url(url, then_callback) {
  request(url, (error, response, body) => {
    if (!error && !body.match(/removed/)) {
      then_callback();
    }
  });
}

function find_text_xpath(path) {
  return driver.wait(until.elementLocated(By.xpath(path)), 5000, 'timeout').then(() => {
    return driver.findElement(By.xpath(path)).then((elem) => {
      return elem.getText();
    });
  });
}

function get_info_from_adult_film_database(movie) {
  find_image_or(
    'body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(1) > table > tbody > tr:nth-child(1) > td > img',
    'body > table > tbody > tr > td > table > tbody > tr > td > table > tbody > tr > td > span > a > img').then((elem) => {
    elem.getAttribute('src').then((src) => {
      let hi_src = src.replace(/\/200\//, '/350/');
      movie.image_url = src;
      check_url(hi_src, () => {
        movie.image_url = hi_src;
      });

      // find_text_xpath("//table/tbody/tr/td/table/tbody/tr/td/table/tbody/tr/td/br/..").then (text) ->
      find_text_xpath('/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[6]/td').then((text) => {
        movie.summary = text;
      });
      find_text_xpath('/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[3]/td[2]').then((text) => {
        if (text.match(/\d\d\d\d/)) {
          movie.year = text;
        }
      });
    });
  });
}

function find_image(selector) {
  return driver.wait(until.elementLocated(By.css(selector)), 5000).then(() => {
    return driver.findElement(By.css(selector));
  });
}

function get_info_from_andrew_blake_com(movie) {
  find_image('#product_thumbnail').then((elem) => {
    elem.getAttribute('src').then((src) => {
      movie.image_url = src;
      find_text_xpath('//*[@id="center-main"]/div[2]/div/div/div[2]/form/table[1]/tbody/tr/td/p[1]').then((text) => {
        movie.summary = text;
      });
    });
  });
}

function scrape_andrew_blake(movie, entry) {
  search_and_click(movie, 'adultfilmdatabase.com').then(() => {
    get_info_from_adult_film_database(movie);
  }, () => {
    search_and_click(movie, 'store.andrewblake.com').then(() => {
      get_info_from_andrew_blake_com(movie);
    });
  }).then(() => {
    win_man.close_tabs().then(() => {
      enter_data(movie, entry);
    });
  });
}

// scrape wow girls
function scrape_wow_girls(entry, title) {
  click('div.modal-header > button.close').then(() => {
    var movie = {
      full_title: title,
      year: null,
      summary: title,
      image_url: null
    };
    enter_data(entry, movie);
  });
}

// send keys via system events
function send_os_keys(keys, enter) {
  let enter_str = '';
  if (enter) {
    enter_str = 'keystroke return';
  }
  spawn_sync('osascript', ['-e', `tell application "System Events"\nkeystroke "${keys}"\n${enter_str}\nend tell`]);
}

function scrape_xart(entry, filename) {
  var movie = parse_movie(filename, 'x-art');
  search_and_click(movie, 'x-art.com/galleries').then(() => {
    find_text_xpath('//*[@id="content"]/div[1]/div[2]/div/p[2]').then((text) => {
      movie.summary = text;
      find_image('img.gallery-cover').then((elem) => {
        driver.actions().mouseMove(elem).mouseDown(webdriver.Button.RIGHT).perform().then(() => {
          send_os_keys('s', 'enter');
          rm('~/Downloads/temp.jpg');
          driver.sleep(2000).then(() => {
            send_os_keys('temp', 'enter');
            driver.sleep(1000).then(() => {
              win_man.close_tabs().then(() => {
                click('div.modal-header > button.close').then(() => {
                  movie.image_url = `file://${process.env.HOME}/Downloads/temp.jpg`;
                  enter_data(entry, movie);
                });
              });
            });
          });
        });
      });
    });
  });
}

// scrape item by file name
function scrape_file_name(entry) {
  driver.actions().mouseMove(entry).perform();
  click_child(entry, 'button.more-btn');
  click('div.media-actions-dropdown > ul.dropdown-menu > li > a.info-btn');
  driver.sleep(1000);
  get_text('div.files > ul.media-info-file-list.well > li').then((text) => {
    var title = basename(last_path(text));
    if (title.match(/wowgirls/i)) {
      scrape_wow_girls(entry, title);
    } else {
      scrape_xart(entry, title);
    }
  });
}

// scrape ith item
function scrape_i(i) {
  find_item('a.media-list-inner-item.show-actions', i).then((entry) => {
    driver.sleep(80).then(() => {
      get_child_text(entry, 'p.media-summary').then((summary) => {
        if (summary) {
          scrape_i(i + 1);
        } else {
          get_child_text(entry, 'span.media-title').then((text) => {
            if (text.match(/andrew.blake/i)) {
              var movie = parse_movie(text, 'andrew blake');
              scrape_andrew_blake(movie, entry);
              next_i = i + 1;
            } else {
              scrape_file_name(entry);
              next_i = i + 1;
            }
          });
        }
      });
    });
  });
}

ipc.on('scrape', (event, arg) => {
  var options = new chrome.Options()
      .addArguments('user-data-dir=/Users/apple/hobby/atomaid/Chrome');

  driver = new webdriver.Builder()
          .forBrowser('chrome')
          .setChromeOptions(options)
          .build();

  driver.get('http://127.0.0.1:32400/web/index.html');
  win_man = new WinMan(driver);
  click_xpath('//span[text() = "porn"]');
  // driver.quit();
  scrape_i(0);
});

ipc.on('scrape_next', (event, arg) => {
  scrape_i(next_i);
});
