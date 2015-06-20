require "selenium-webdriver"
require "open-uri"

class Movie
  attr_accessor :image_url, :studio, :year, :director, :summary, :full_title
end

class Scraper
  def find_entry(i)
    entries = @browser.find_elements(css: "a.media-list-inner-item.show-actions")
    if i >= entries.count
      i = i % entries.count
    end
    entries[i].location_once_scrolled_into_view()
    # @browser.execute_script('arguments[0].scrollIntoView(true);', entries[i]);
    return entries[i]
  end

  def wait(selector)
    if selector.start_with?('/')
      @wait.until { @browser.find_element(xpath: selector)}
    else
      @wait.until { @browser.find_element(css: selector)}
    end
  end

  def find_element(selector)
    wait(selector)
    if selector.start_with?('/')
      return @browser.find_element(xpath: selector)
    else
      return @browser.find_element(css: selector)
    end
  end

  def find_elements(*selectors)
    selector1, selector2 = *selectors
    if selector1.start_with?('/')
      elements = @browser.find_elements(xpath: selector1)
    else
      elements = @browser.find_elements(css: selector1)
    end
    if elements.length == 0
      if selector2.start_with?('/')
        elements = @browser.find_elements(xpath: selector2)
      else
        elements = @browser.find_elements(css: selector2)
      end
    end
    return elements
  end

  def click(selector)
    if selector.start_with?('/')
      @browser.find_element(xpath: selector).click
    else
      @browser.find_element(css: selector).click
    end
  end

  def click_child(entry, css)
    entry.find_element(css: css).click
  end

  def send_keys(selector, str)
    if selector.start_with?('/')
      elem = @browser.find_element(xpath: selector)
    else
      elem = @browser.find_element(css: selector)
    end
    elem.click
    elem.clear
    elem.send_keys(str, :enter)
  end

  def send_os_keys(*args)
    if args.last == :enter
      enter_str = 'keystroke return'
      keys = args[0]
    else
      enter_str = ''
      keys = args[0]
    end
    system('osascript', '-e', "tell application \"System Events\"\nkeystroke \"#{keys}\"\n#{enter_str}\nend tell")
  end

  def find_filename(entry)
    @browser.action.move_to(entry).perform
    click_child(entry, 'button.more-btn')
    click('div.media-actions-dropdown > ul.dropdown-menu > li > a.info-btn')
    sleep(1)
    filename = find_element('div.files > ul.media-info-file-list.well > li').text
    click('div.modal-header > button.close')
    sleep(1)
    return filename
  end

  def switch_to_new()
    sleep(1) # wait new tab open
    windows = @browser.window_handles()
    windows.each do |win|
      if !@windows.include?(win)
        @windows.push(win)
        @browser.switch_to().window(win)
        break
      end
    end
    sleep(1) # wait new tab load
  end

  def open_tab()
    @browser.execute_script('window.open()')
    switch_to_new()
  end

  def close_tab()
    @browser.close()
    @windows.pop()
    @browser.switch_to().window(@windows.last)
  end

  def send_enter(str)
    find_element('#lst-ib').send_keys(str, :enter)
  end

  def search(words)
    open_tab()
    @browser.get('https://google.com')
    send_enter(words)
    sleep(1)
  end

  def search_term(path)
    %r{([^/]+)\/([^/]+)\.[^.]+$} =~ path
    file = $2
    folder = $1
    if file =~ /chi-jdbbmm/
      term = folder
    else
      term = file
    end
    return term
      .sub(/ - cd\d/i, '')
      .sub(/chi-/, '')
      .sub(/james deen's /i, '')
      .sub(/\./, ' ')
      .sub(/x-art - [^-]+ - (.+)/i, '\1')
      .sub(/joymii - [^-]+ - (.+)/i, '\1')
  end

  def title_from(path)
    search_term(path).split(' ').map {|w| w.capitalize}.join(' ')
  end

  def normalize(filename)
    return File.basename(filename, '.*')
      .sub('X-art', 'X-Art')
  end

  def try_find(css)
    3.times do
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

  def find_image(*css)
    css1, css2 = *css
    elem = try_find(css1)
    return elem if elem
    elem = try_find(css2)
    return elem if elem
    return nil
  end

  def download_image(css)
    image = find_image(css)
    @browser.action.move_to(image).context_click().perform
    send_os_keys('s', :enter)
    system('rm', "-f", "#{Dir.home}/Downloads/temp.jpg")
    sleep(2)
    send_os_keys('temp', :enter)
    sleep(1)
  end

  def download_image_new_tab(url)
    open_tab()
    @browser.get(url)
    download_image('img')
  end

  def scrape_general(entry, filename, kind, site)
    s_term = search_term(filename)

    search("#{s_term} site:#{site}")
    candi = []
    prio = 50

    find_elements('#rso li > div > h3 > a').each do |elem|
      if elem.text =~ /\d/ && s_term =~ /\d$/
        candi.push([elem, 200 + prio])
      end
      if elem.text !~ /\d/ && s_term !~ /\d$/
        candi.push([elem, 100 + prio])
      end
      if elem.text =~ /gallery/i
        candi.push([elem, 300 + prio])
      end
      if elem.text =~ / - video .../i
        if elem.text.downcase.include?(s_term.downcase)
          candi.push([elem, 400 + prio])
        end
      end
      prio -= 1
    end
    candi.sort! { |a, b| b[1] <=> a[1] }
    candi[0][0].click

    switch_to_new()

    movie = Movie.new
    yield movie

    close_tab() # adultfilmdatabase tab
    close_tab() # google search tab

    @browser.action.move_to(entry).perform
    click_child(entry, 'button.edit-btn')
    sleep(1) # wait dialog open

    send_keys('/html/body/div[4]/div/div/div[2]/div[2]/div/form/div[1]/div/div/div/div/div[1]/input', movie.full_title);
    if movie.year
      send_keys('input#lockable-year', movie.year)
    end
    if movie.studio
      send_keys('/html/body/div[4]/div/div/div[2]/div[2]/div/form/div[5]/div[1]/div/div/div/div[1]/input', movie.studio)
    end
    send_keys('//*[@id="lockable-summary"]', movie.summary)
    if movie.director
      click('a.change-pane-btn.tags-btn')
      send_keys('/html/body/div[4]/div/div/div[2]/div[2]/div/form/div[1]/div[1]/div/div/div/div[1]/input', movie.director)
    end
    if movie.image_url
      click('a.change-pane-btn.poster-btn')
      click('a.upload-url-btn')
      send_keys('//*[@id="upload-form"]/input', movie.image_url)
      sleep(2) # wait uploading
    end
    click('button.save-btn.btn-loading')
  end

  def scrape_andrew_blake(entry, filename)
    scrape_general(entry, filename, 'andrew blake', 'adultfilmdatabase.com') do |movie|
      image = find_image('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(1) > table > tbody > tr:nth-child(1) > td > img',
                         'body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(1) > table > tbody > tr:nth-child(1) > td > a > img')
      movie.image_url = image.attribute('src')
      hi_src = movie.image_url.sub('200', '350')
      open(hi_src) { |f|
        movie.image_url = hi_src
      }

      movie.studio = find_element('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(2) > table:nth-child(9) > tbody > tr:nth-child(2) > td:nth-child(2) > u > a').text
      movie.year = find_element('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(2) > table:nth-child(9) > tbody > tr:nth-child(3) > td:nth-child(2)').text
      movie.director = find_element('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(2) > table:nth-child(9) > tbody > tr:nth-child(4) > td:nth-child(2) > a').text
      movie.summary = find_element('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(2) > table:nth-child(9) > tbody > tr:nth-child(6) > td').text
      movie.full_title = 'Andrew Blake - ' + s_term
    end
  end


  def scrape_james_deen(entry, filename)
    scrape_general(entry, filename, 'james deen', 'jamesdeenproductions.com') do |movie|
      image = find_image('img.attachment-product-image.wp-post-image')

      movie.image_url = image.attribute('src')
      movie.studio = 'James Deen Productions'
      movie.year = nil
      movie.director = nil
      movie.summary = find_element('/html/body/div[1]/div/main/section/div/div/div[1]/p[2]').text
      movie.full_title = 'James Deen - ' + title_from(filename)
    end
  end

  def scrape_x_art(entry, filename)
    scrape_general(entry, filename, 'x-art', 'x-art.com/galleries') do |movie|
      sleep(5)
      download_image('img.gallery-cover')

      movie.image_url = "file://#{Dir.home}/Downloads/temp.jpg"
      movie.studio = 'X-Art'
      if find_element('//*[@id="content"]/ul/li[1]').text =~ /.+(\d\d\d\d)/
        movie.year = $1
      end
      movie.summary = find_element('//*[@id="content"]/div[1]/div[2]/div/p').text
      if movie.summary == ''
        movie.summary = find_element('//*[@id="content"]/div[1]/div[2]/div/p[2]').text
      end
      movie.full_title = normalize(filename)
    end
  end

  def scrape_joy_mii(entry, filename)
    scrape_general(entry, filename, 'joymii', 'joymii.com/site/set-video') do |movie|
      sleep(1)
      image = find_image('div.video-container > div.video-js', '#video-placeholder > img.poster')
      url = image.attribute('poster')
      if !url
        url = image.attribute('src')
      end
      download_image_new_tab(url)
      close_tab()
      movie.image_url = "file://#{Dir.home}/Downloads/temp.jpg"
      movie.studio = 'JoyMii'
      movie.summary = find_element('div.info > p.text').text
      title = find_element('h1.title').text
      actors = find_elements('h2.starring-models > a').map { |elem| elem.text }.join(', ')
      movie.full_title = "JoyMii - #{actors} - #{title}"
    end
  end

  def scrape_entry(entry)
    title = entry.find_element(css: "span.media-title").text
    filename = find_filename(entry)
    if filename =~ /andrew blake/i
      scrape_andrew_blake(entry, filename)
    elsif filename =~ /james deen/i
      scrape_james_deen(entry, filename)
    elsif filename =~ /x-art/i
      scrape_x_art(entry, filename)
    elsif filename =~ /joymii/i
      scrape_joy_mii(entry, filename)
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
      sleep(0.15)
      summary = entry.find_element(css: "p.media-summary")
      if summary.text == ''
        scrape_entry(entry)
        sleep(3)
      else
        i += 1
      end
    end
  end
end

scraper = Scraper.new
scraper.scrape
