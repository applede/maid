require "selenium-webdriver"

class Movie
  attr_accessor :image_url
end

class Scraper
  def find_entry(i)
    entries = @browser.find_elements(css:"a.media-list-inner-item.show-actions")
    if i < entries.count
      entries[i].location_once_scrolled_into_view()
      # @browser.execute_script('arguments[0].scrollIntoView(true);', entries[i]);
      return entries[i]
    else
      return find_entry(i % entries.count)
    end
  end

  def wait(css)
    @wait.until { @browser.find_element(css: css)}
  end

  def find_element(css)
    wait(css)
    return @browser.find_element(css: css)
  end

  def click(css)
    @browser.find_element(css:css).click
  end

  def click_child(entry, css)
    entry.find_element(css:css).click
  end

  def find_filename(entry)
    @browser.action.move_to(entry).perform
    click_child(entry, 'button.more-btn')
    click('div.media-actions-dropdown > ul.dropdown-menu > li > a.info-btn')
    sleep(1)
    filename = find_element('div.files > ul.media-info-file-list.well > li').text
    click('div.modal-header > button.close')
    return filename
  end

  def switch_to_new()
    windows = @browser.window_handles()
    windows.each do |win|
      if !@windows.include?(win)
        @windows.push(win)
        @browser.switch_to().window(win)
        break
      end
    end
  end

  def open_tab()
    @browser.execute_script('window.open()')
    switch_to_new()
  end

  def send_enter(str)
    find_element('#lst-ib').send_keys(str, :enter)
  end

  def search(words)
    open_tab()
    @browser.get('https://google.com')
    send_enter(words)
  end

  def search_term(path)
    /([^\/]+)\.[^\.]+$/ =~ path
    return $1.gsub(/ +cd\d/i, '')
  end

  def try_find(css)
    5.times do
      begin
        elem = @browser.find_element(css: css)
      rescue
        elem = nil
      end
      if elem
        return elem
      end
      sleep(1)
    end
    return nil
  end

  def find_image(css1, css2)
    elem = try_find(css1)
    return elem if elem
    elem = try_find(css2)
    return elem if elem
    return nil
  end

  def scrape_andrew_blake(entry, filename)
    search('andrew blake ' + search_term(filename) + ' site:adultfilmdatabase.com')
    find_element('ol > div.srg > li.g > div.rc > h3.r > a').click
    sleep(1)
    switch_to_new()
    sleep(1)
    image = find_image('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(1) > table > tbody > tr:nth-child(1) > td > img',
                       'body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(1) > table > tbody > tr:nth-child(1) > td > a > img')
    movie = Movie.new
    movie.image_url = image.attribute('src')
    hi_src = movie.image_url.sub('200', '350')
    open(hi_src) { |f|
      movie.image_url = hi_src
    }

    puts movie.image_url
  end

  def scrape_entry(entry)
    title = entry.find_element(css:"span.media-title").text
    filename = find_filename(entry)
    if filename =~ /andrew blake/i
      scrape_andrew_blake(entry, filename)
    end
  end

  def scrape
    @browser = Selenium::WebDriver.for :chrome, :switches => %w[--user-data-dir=./Chrome]
    @browser.get "http://127.0.0.1:32400/web/index.html"
    @wait = Selenium::WebDriver::Wait.new(:timeout => 5)
    wait("span.section-title")
    @windows = @browser.window_handles()
    @browser.find_elements(css: "span.section-title").each do |elem|
      if elem.text == 'porn'
        elem.click
        break
      end
    end
    wait("a.media-list-inner-item.show-actions")

    i = 0
    while true
      entry = find_entry(i)
      sleep(0.1)
      summary = entry.find_element(css:"p.media-summary")
      if summary.text == ''
        scrape_entry(entry)
        break
      else
        i += 1
      end
    end
  end
end

scraper = Scraper.new
scraper.scrape
