require "selenium-webdriver"
require "open-uri"

class Movie
  attr_accessor :image_url, :studio, :year, :director, :summary, :full_title, :title, :actors,
                :runtime, :genre, :mpaa
end

class Scraper
  def nfo_file(path)
    return path.sub(/\.[^.]+$/, '.nfo')
  end

  def need_nfo(path)
    if /\.(mkv|mov|mp4|avi|wmv)$/ =~ path
      nfo = nfo_file(path)
      if File.exist?(nfo)
        nfo_time = File.new(nfo).mtime
        file_time = File.new(path).mtime
        return nfo_time < file_time
      else
        return true
      end
    else
      return false
    end
  end

  def url_exist?(url)
    begin
      open(url)
      return true
    rescue
      return false
    end
  end

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

  def try_find(selector)
    3.times do
      begin
        if selector.start_with?('/')
          return @browser.find_element(xpath: selector)
        else
          return @browser.find_element(css: selector)
        end
      rescue
      end
      sleep(1)
    end
    return nil
  end

  def find_element(*selectors)
    selector1, selector2 = *selectors
    elem = try_find(selector1)
    return elem if elem
    elem = try_find(selector2)
    return elem if elem
    return nil
  end

  def find_elements(*selectors)
    selector1, selector2 = *selectors
    if selector1.start_with?('/')
      elements = @browser.find_elements(xpath: selector1)
    else
      elements = @browser.find_elements(css: selector1)
    end
    if elements.length == 0 && selector2
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
    if file =~ /andrew_blake/i
      return folder
    end
    return term
      .sub(/ - cd\d/i, '')
      .sub(/chi-/, '')
      .sub(/james deen's /i, '')
      .sub(/\./, ' ')
      .sub(/x-art - [^-]+ - (.+)/i, '\1')
      .sub(/joymii - [^-]+ - (.+)/i, '\1')
      .gsub(/_/, ' ')
  end

  def does_match(text, path)
    %r{([^/]+)\/([^/]+)\.[^.]+$} =~ path
    file = $2
    folder = $1
    name = file.gsub(/_/, ' ')
               .sub(/^andrew blake \d\d\d\d - /i, '')
               .sub(/ and /i, ' & ')
               .sub(/^the /i, '')
    name = name.split(' - ')[0]
    return text.downcase.include?(name.downcase)
  end

  def extra_name(path)
    %r{([^/]+)\/([^/]+)\.[^.]+$} =~ path
    file = $2
    folder = $1
    name = file.gsub(/_/, ' ')
               .sub(/^andrew blake \d\d\d\d - /i, '')
               .sub(/ - ntsc$/i, '')
               .sub(/ ntsc$/i, '')
    parts = name.split(' - ')
    if parts.length > 1
      return ' - ' + parts[1..-1].join(' - ')
    end
    return ''
  end

  def title_from(path)
    search_term(path).split(' ').map {|w| w.capitalize}.join(' ')
  end

  def normalize(filename)
    return File.basename(filename, '.*')
      .sub('X-art', 'X-Art')
  end

  def download_image(css)
    image = find_element(css)
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

  def scrape_general(path, kind, site)
    candi = []
    prio = 50

    if kind == 'andrew blake'
      open_tab()
      @browser.get('http://www.adultfilmdatabase.com/director.cfm?directorid=165')
      new_tab = false

      find_elements('/html/body/table[3]/tbody/tr/td[1]/table/tbody/tr[5]/td/table/tbody/tr[1]/td/table/tbody/tr/td[1]/span/a').each do |elem|
        if does_match(elem.text, path)
          candi.push([elem, 100 + 99 - elem.text.length])
        end
      end
      if candi.empty?
        close_tab()
        return false
      end
    else
      s_term = search_term(path)

      search("#{s_term} site:#{site}")
      new_tab = true

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
        if elem.text =~ / dvd - vod - /i
          if elem.text.downcase.include?(s_term.downcase)
            candi.push([elem, 500 + prio])
          end
        end

        prio -= 1
      end
    end

    candi.sort! { |a, b| b[1] <=> a[1] }
    candi[0][0].click

    if new_tab
      switch_to_new()
    end

    movie = Movie.new
    yield movie

    if new_tab
      close_tab() # adultfilmdatabase tab
    end
    close_tab() # google search tab

    actors = ''
    movie.actors.each do |actor|
      actors += <<-END_ACTOR
  <actor>
    <name>#{actor}</name>
  </actor>
END_ACTOR
    end
    nfo = path.sub(/\.[^.]+$/, '.nfo')
    open(nfo, 'w') do |file|
      file.puts <<-END_NFO
<movie>
  <title>#{movie.title}</title>
  <year>#{movie.year}</year>
  <plot>#{movie.summary}</plot>
  <runtime>#{movie.runtime}</runtime>
  <director>#{movie.director}</director>
  <genre>#{movie.genre}</genre>
  <studio>#{movie.studio}</studio>
  <mpaa>#{movie.mpaa}</mpaa>
#{actors}
</movie>
END_NFO
    end
    image = path.sub(/\.[^.]+$/, '-poster.jpg')
    open(image, 'wb') do |local_file|
      open(movie.image_url, 'rb') do |remote_file|
        local_file.write(remote_file.read)
      end
    end
    return true
  end

  def scrape_andrew_blake(path)
    done = scrape_general(path, 'andrew blake', 'adultfilmdatabase.com') do |movie|
      extra = extra_name(path)
      if extra != ''
        image = find_element('/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[1]/table/tbody/tr[2]/td/a/img',
                             '/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[1]/table/tbody/tr[1]/td/img')
      else
        image = find_element('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(1) > table > tbody > tr:nth-child(1) > td > img',
                             'body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(1) > table > tbody > tr:nth-child(1) > td > a > img')
      end
      movie.image_url = image.attribute('src')
      hi_src = movie.image_url.sub('200', '350')
      if url_exist?(hi_src)
        movie.image_url = hi_src
      end

      movie.studio = find_element('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(2) > table:nth-child(9) > tbody > tr:nth-child(2) > td:nth-child(2) > u > a',
                                  '/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[2]/td[2]/u/a').text
      movie.year = find_element('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(2) > table:nth-child(9) > tbody > tr:nth-child(3) > td:nth-child(2)',
                                '/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[3]/td[2]').text
      movie.director = find_element('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(2) > table:nth-child(9) > tbody > tr:nth-child(4) > td:nth-child(2) > a',
                                    '/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[4]/td[2]/a').text
      movie.summary = find_element('body > table:nth-child(7) > tbody > tr > td > table:nth-child(1) > tbody > tr > td:nth-child(2) > table:nth-child(9) > tbody > tr:nth-child(6) > td',
                                   '/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[6]/td').text
      movie.title = find_element('/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/span').text + extra
      movie.actors = find_elements('/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[1]/tbody/tr/td/div/span/a/u').map { |elem| elem.text }
      movie.runtime = find_element('/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[1]/td[2]').text
      movie.genre = find_element('/html/body/table[3]/tbody/tr/td/table[1]/tbody/tr/td[2]/table[2]/tbody/tr[5]/td[2]').text
      movie.mpaa = 'X'
    end
    unless done
      scrape_general(path, 'ab', 'store.andrewblake.com') do |movie|
        image = find_element('#product_thumbnail')
        movie.image_url = image.attribute('src')
        if /\b\d\d\d\d\b/ =~ path
          movie.year = $&
        end
        movie.studio = ''
        movie.title = find_element('//*[@id="center-main"]/h1').text.sub(/ DVD$/, '') + extra_name(path)
        movie.genre = ''
        movie.mpaa = 'X'
        find_elements('//*[@id="center-main"]/div[2]/div/div/div[2]/form/table[1]/tbody/tr/td/p').each do |elem|
          if !movie.summary
            movie.summary = elem.text
          end
          if elem.text.start_with?('Starring: ')
            movie.actors = elem.text[10..-1].split(', ')
          end
          if elem.text.start_with?('Directed')
            movie.director = elem.text.split(' by ')[-1]
          end
          if /(\d+) minute feature film/i =~ elem.text
            movie.runtime = $1
          end
        end
      end
    end
  end


  def scrape_james_deen(path)
    scrape_general(path, 'james deen', 'jamesdeenproductions.com') do |movie|
      image = find_element('img.attachment-product-image.wp-post-image')

      movie.image_url = image.attribute('src')
      movie.studio = 'James Deen Productions'
      movie.year = nil
      movie.director = nil
      movie.summary = find_element('/html/body/div[1]/div/main/section/div/div/div[1]/p[2]').text
      movie.full_title = 'James Deen - ' + title_from(path)
    end
  end

  def scrape_x_art(path)
    scrape_general(path, 'x-art', 'x-art.com/galleries') do |movie|
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
      movie.full_title = normalize(path)
    end
  end

  def scrape_joy_mii(path)
    scrape_general(path, 'joymii', 'joymii.com/site/set-video') do |movie|
      sleep(1)
      image = find_element('div.video-container > div.video-js', '#video-placeholder > img.poster')
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

  def scrape_file(path)
    if path =~ /andrew blake|andrew_blake/i
      scrape_andrew_blake(path)
    elsif path =~ /james deen/i
      scrape_james_deen(path)
    elsif path =~ /x-art/i
      scrape_x_art(path)
    elsif path =~ /joymii/i
      scrape_joy_mii(path)
    end
  end

  def traverse(folder, &block)
    Dir.entries(folder).each do |file|
      unless file.start_with?('.')
        path = File.join(folder, file)
        if File.directory?(path)
          traverse(path, &block)
        else
          if need_nfo(path)
            block.call(path)
          end
        end
      end
    end
  end

  def scrape
    @browser = Selenium::WebDriver.for :chrome, :switches => %w[--user-data-dir=./Chrome]
    @wait = Selenium::WebDriver::Wait.new(:timeout => 5)
    @windows = @browser.window_handles()

    traverse('/Users/apple/mount/public/porn') do |path|
      puts path
      scrape_file(path)
    end
  end
end

scraper = Scraper.new
scraper.scrape
