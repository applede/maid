maidApp = angular.module('maid', ['ngRoute', 'maidControllers', 'scraper', 'ui.bootstrap']);

maidApp.config ['$routeProvider',
  ($routeProvider) ->
    $routeProvider
    .when '/home',
      templateUrl: 'home.html',
      controller: 'HomeCtrl'
    .when '/transfers',
      templateUrl: 'transfers.html',
      controller: 'TransferCtrl'
    .when '/rules',
      templateUrl: 'rules.html',
      controller: 'RulesCtrl'
    .when '/images',
      templateUrl: 'images.html',
      controller: 'ImagesCtrl'
    .when '/scraping',
      templateUrl: 'scraping.html',
      controller: 'ScrapingCtrl'
    .when '/settings',
      templateUrl: 'settings.html',
      controller: 'SettingsCtrl'
    .otherwise
      redirectTo: '/home'
]

maidControllers = angular.module('maidControllers', [])

maidControllers.controller 'MenuCtrl', ['$scope', '$location', ($scope, $location) ->
  $scope.is_active = (loc) ->
    loc == $location.path()
]

last_elem = (array) ->
  array[array.length - 1]

remote = require 'remote'
ipc = require 'ipc'
exec = require('child_process').exec
fs = require 'fs'
pouchdb = require 'pouchdb'
spawn = require('child_process').spawn
spawn_sync = require('child_process').spawnSync
Path = require 'path'
unorm = require 'unorm'

db = new pouchdb('rules', {adapter: 'idb'})
settings_db = new pouchdb('settings', {adapter: 'idb'})

settings = {}

load_settings = (callback) ->
  settings_db.allDocs {include_docs: true}, (err, resp) ->
    if resp.rows[0]
      settings = resp.rows[0].doc
    else
      home = process.env['HOME']
      settings =
        tvshow_folder: "#{home}/Downloads/tvshows"
        porn_folder: "#{home}/Downloads/porns"
        movie_folder: "#{home}/Downloads/movies"
    callback(settings)

load_settings(->
)

max_order = 1

next_order = ->
  max_order += 1
  max_order

load_rules = (scope, callback) ->
  rules = []
  db.allDocs {include_docs: true}, (err, response) ->
    rules = (row.doc for row in response.rows)
    rules.sort((a, b) -> a.order - b.order)
    max_order = rules[rules.length - 1].order
    callback(rules)

contains = (str, sub) ->
  str.indexOf(sub) != -1

exists = (path) ->
  fs.existsSync(path)

is_dir = (path) ->
  fs.statSync(path).isDirectory()

is_symlink = (path) ->
  fs.lstatSync(path).isSymbolicLink()

dir_entry = (path) ->
  fs.readdirSync(path)

basename = (filename) ->
  compo = filename.split('.')
  if compo.length == 1
    filename
  else
    compo.pop()
    compo.join('.')

last_path = (path) ->
  if path
    compo = path.split('/')
    compo.pop()

ext = (filename) ->
  compo = filename.split('.')
  if compo.length == 1
    ""
  else
    compo.pop()

folder_for_rule = (rule) ->
  switch rule.kind
    when 'movie'
      settings.movie_folder
    when 'tvshow'
      settings.tvshow_folder
    when 'porn'
      settings.porn_folder
    else
      throw "unknown kinds #{rule.kind}"

is_regexp = (str) ->
  str.match(/\$[0-9]/)

regexp = (str) ->
  option = if str.match(/[A-Z]/) then "" else "i"
  try
    r = new RegExp(str, option)
  catch e
    r = new RegExp(".+")
  r

whole_regexp = (str) ->
  regexp("^#{str}$")

dst_folder = (entry) ->
  if entry.rule.name && is_regexp(entry.rule.name)
    renamed(entry.rule, entry.name, entry.folder, entry.rule.name, true)
  else
    entry.rule.name

normalize = (str) ->
  unorm.nfd(str)

match_rule = (rule, file, folder) ->
  if rule && rule.include_folder
    file = Path.join(last_path(folder), file)
  rule && ext(file).match(whole_regexp(rule.ext)) &&
  rule.pattern && basename(normalize(file)).match(regexp(normalize(rule.pattern)))

apply_rules = (rules, file, folder) ->
  for rule in rules
    if match_rule(rule, file, folder)
      return rule
  null

add_or_update_rule = (rule, callback) ->
  if !rule._id
    rule.order = next_order()
    db.post rule, (err, response) ->
      if callback
        callback()
  else
    db.put rule, (err, response) ->
      if callback
        callback()

find_prev_rule = (rules, rule) ->
  prev = null
  for r in rules
    if r.order == rule.order
      return prev
    prev = r

swap_rule = (a, b) ->
  temp = a.order
  a.order = b.order
  b.order = temp

maid_actions =
  [
    { label: 'Ignore', value: 'ignore' },
    { label: 'Copy', value: 'copy' },
    { label: 'Unrar', value: 'unrar' },
  ]

maid_kinds =
  [
    { label: 'TV Show', value: 'tvshow' },
    { label: 'Movie', value: 'movie' },
    { label: 'Porn', value: 'porn' },
  ]

kind_display = (value) ->
  for k in maid_kinds
    return k.label if k.value == value

capitalize = (str) ->
  if str
    if str[0] == '('
      str[0] + str[1].toUpperCase() + str[2 ..].toLowerCase()
    else if str == 'II'
      str
    else
      str[0].toUpperCase() + str[1 ..].toLowerCase()

capitalize_each = (str) ->
  if str
    (capitalize(s) for s in str.split(' ')).join(' ')

get_int = (str, index) ->
  orig = index
  while str[index] >= '0' && str[index] <= '9'
    index += 1
  {value:parseInt(str[orig ..]), len:index - orig}

renamed = (rule, file, folder, rename, no_ext) ->
  if rule && rule.pattern && rule.rename && file
    if rule.include_folder
      file_name = Path.join(last_path(folder), file)
    else
      file_name = file
    m = basename(normalize(file_name)).match(regexp(normalize(rule.pattern)))
    if m
      for i in [1 .. 9]
        index = rename.indexOf("$#{i}")
        if index == -1
          break
        end = index + 2
        sub = m[i] || ""
        while true
          modifier = rename[end .. end + 1]
          if modifier == ':c'
            sub = capitalize(sub)
          else if modifier == ':C'
            sub = capitalize_each(sub)
          else if modifier == ':.'
            sub = sub.replace(/\./g, ' ')
          else if modifier == ':_'
            sub = sub.replace(/_/g, ' ')
          else if modifier == ':-'
            r = get_int(rename, end + 2)
            sub = ("0" + (parseInt(sub) - r.value)).slice(-2)
            end += r.len
          else if modifier == ':0'
            sub = ("00" + sub).slice(-2)
          else
            break
          end += 2
        rename = rename.replace(rename[index ... end], sub)
    basename(normalize(file_name)).replace(regexp(normalize(rule.pattern)), rename) +
      if no_ext then "" else "." + ext(file)
  else
    file

matching_rule = (file, rules, files, folder) ->
  rule = apply_rules(rules, file, folder)
  if rule
    files.push({name: file, rule: rule, folder: folder, renamed: renamed(rule, file, folder, rule.rename)})
    return true
  else
    files.push({name: file, rule: {action: "no match"}, folder: folder})
    return false

process_files = (name, location, rules) ->
  path = Path.join(location, name)
  if exists(path)
    files = []
    if is_dir(path)
      for file in dir_entry(path)
        sub_path = Path.join(path, file)
        if is_dir(sub_path)
          for sub_file in dir_entry(sub_path)
            if !matching_rule(Path.join(file, sub_file), rules, files, path)
              return files
        else
          if !matching_rule(file, rules, files, path)
            return files
    else
      matching_rule(name, rules, files, location)
  else
    files = [{name: 'Not exists', rule: {action: 'remove'}}]
  return files

process_transmission = (rules) ->
  lines = spawn_sync('/usr/local/bin/transmission-remote', ['--list']).stdout.toString()
  transfers = []
  for line in lines.split("\n")
    tid = line[0 .. 4].trim()
    name = line[70 .. -1]
    status = line[57 .. 69].trim()
    if status == "Finished"
      infos = spawn_sync('/usr/local/bin/transmission-remote', ['-t', tid, '--info']).stdout.toString()
      for info in infos.split("\n")
        if info[0 .. 11] == "  Location: "
          location = info[12 .. -1]
          path = Path.join(location, name)
          # files = []
          # if exists(path)
          files = process_files(name, location, rules)
          transfers.push { tid: tid, name: name, files: files, path: path, status: status }
          # if is_dir(path)
          #   for file in dir_entry(path)
          #     sub_path = Path.join(path, file)
          #     if is_dir(sub_path)
          #       for sub_file in dir_entry(sub_path)
          #         last_action = process_file(Path.join(file, sub_file), rules, files, path)
          #         if last_action == 'no match'
          #           break
          #     else
          #       last_action = process_file(file, rules, files, path)
          #     if last_action == 'no match'
          #       break
          # else
          #   last_action = process_file(name, rules, files, location)
          # transfers.push {tid: tid, name: name, files: files, path: path, status: status}
          # else
          #   transfers.push {
          #     tid: tid,
          #     name: name,
          #     files: [{name: 'Not exists', rule: {action: 'remove'}}],
          #     path: path,
          #     status: status}
          if last_elem(last_elem(transfers).files).rule.action == 'no match'
            return transfers
          break
  transfers

scroll_to_bottom = ->
  window.scrollTo(0, document.body.scrollHeight)

logger = []

reset_log = ($scope) ->
  logger = []
  $scope.running = logger

log = (str, cls) ->
  logger.push {class:cls || '', str:str}

exec_log = (cmd) ->
  log cmd
  exec(cmd)

spawn_log = (cmd, args, cls) ->
  if cmd != "echo"
    log "#{cmd} #{args.join(' ')}", cls
  spawn cmd, args

spawn_sync_log = (cmd, args) ->
  log "#{cmd} #{args.join(' ')}"
  spawn_sync cmd, args

mkdir_if_not_exist = (path) ->
  compo = path.split('/')
  compo.pop()
  path = compo.join('/')
  if !exists(path)
    spawn_sync_log('mkdir', ['-p', path])

remove_if_exist = (path) ->
  if exists(path)
    spawn_log "rm", ['-rf', path]
  else
    log "File not exist #{path}", "warning"

file_size = (path) ->
  fs.statSync(path).size

pretty_size = (x) ->
  if x >= 1000000000
    (x / 1000000000).toFixed(2) + 'G'
  else if x >= 1000000
    (x / 1000000).toFixed(1) + 'M'
  else if x >= 1000
    (x / 1000).toFixed(1) + 'K'
  else
    x.toString()

copy_if_bigger = (src, dst, $scope, $timeout, callback) ->
  if exists(src)
    src_size = file_size(src)
  else
    log "Not exist #{src}", 'warning'
    return false
  if exists(dst)
    dst_size = file_size(dst)
    if dst_size >= src_size
      log "Skip dst (#{pretty_size(dst_size)}) >= src (#{pretty_size(src_size)}) #{src} #{dst}", 'warning'
      return false
    else
      log "Overwrite dst (#{pretty_size(dst_size)}) < src (#{pretty_size(src_size)})", 'warning'
  else
    mkdir_if_not_exist(dst)
  $scope.progress = 0
  $scope.dst_size = pretty_size(0)
  $timeout ->
    $scope.$apply()
    scroll_to_bottom()
    if exists(dst)
      $scope.watch = fs.watch dst, (event, filename) ->
        if event == 'change'
          dst_size = file_size(dst)
          $scope.progress = ((dst_size / src_size) * 100).toFixed(1)
          old_size = $scope.dst_size
          $scope.dst_size = pretty_size(dst_size)
          if $scope.dst_size != old_size
            $scope.$apply()
  , 100
  cmd = spawn_log 'cp', [src, dst]
  if cmd
    cmd.on 'close', callback
    cmd.stdout.on 'data', (data) ->
      log data.toString()
    cmd.stderr.on 'data', (data) ->
      log data.toString(), 'warning'

unrar = (src, dst, $scope, callback) ->
  cmd = spawn_log '/usr/local/bin/unrar', ['e', '-o+', src, dst]
  if cmd
    cmd.on 'close', callback
    cmd.stdout.on 'data', (data) ->
      log data.toString()
      $scope.$apply()
      scroll_to_bottom()
    cmd.stderr.on 'data', (data) ->
      log data.toString(), 'warning'

process_transfers = (transfers, $scope, $timeout) ->
  while transfer = transfers[0]
    if !transfer.logged
      log "Processing #{transfer.name}", "info"
      transfer.logged = true
    while file = transfer.files.shift()
      switch file.rule.action
        when 'copy'
          src = Path.join(file.folder, file.name)
          dst = Path.join(folder_for_rule(file.rule), dst_folder(file), file.renamed)
          cmd = copy_if_bigger src, dst, $scope, $timeout, (code) ->
            if $scope.watch
              $scope.watch.close()
            if code == 0
              process_transfers transfers, $scope, $timeout
          if cmd
            return
        when 'unrar'
          src = Path.join(file.folder, file.name)
          transfer.unrar = src
          unrar src, file.folder, $scope, (code) ->
            if code == 0
              process_transfers transfers, $scope, $timeout
          return
        when 'no match'
          $scope.running.pop()
          log 'Done', 'success'
          $scope.show_progress = false
          $scope.show_test = true
          $scope.$apply()
          scroll_to_bottom()
          return
    if transfer.unrar
      remove_if_exist(transfer.unrar)
    else
      exec_log "/usr/local/bin/transmission-remote -t #{transfer.tid} --remove", $scope
      remove_if_exist(transfer.path)
    transfers.shift()
  $scope.show_progress = false
  $scope.show_test = true
  $scope.$apply()
  scroll_to_bottom()

maidControllers.controller 'HomeCtrl', ['$scope', '$timeout', '$modal', ($scope, $timeout, $modal) ->
  $scope.test_run = ->
    reset()
    load_rules $scope, (rules) ->
      $scope.transfers = process_transmission rules
      if $scope.transfers.length > 0
        $scope.show_result = true
        $scope.show_test = false
        reset_log($scope)
        if $scope.transfers.length >= 1
          $scope.show_run = true
      else
        $scope.show_message=true
      $scope.$apply()
  $scope.run = ->
    reset_log($scope)
    $scope.show_progress = true
    $scope.show_run = false
    $timeout ->
      process_transfers(angular.copy($scope.transfers), $scope, $timeout)
      $scope.$apply()
      # scroll_to_bottom()

  $scope.result_class = (file) ->
    if file.rule
      switch file.rule.action
        when "copy" then "success"
        when "ignore" then ""
        when "unrar" then "success"
        else "danger"
    else
      "danger"
  $scope.edit_rule = (transfer, entry) ->
    # $scope.entry = entry
    # $scope.dialog.modal('show')
    $scope.entry = angular.copy(entry)
    if $scope.entry.rule.action == 'no match'
      $scope.entry.rule.action = 'ignore'
      $scope.entry.rule.pattern = '.+'
      $scope.entry.rule.ext = ext(entry.name)
    modalInstance = $modal.open
      templateUrl: 'edit_rule_modal.html'
      controller: 'ModalCtrl'
      size: 'lg'
      scope: $scope
      backdrop: 'static'
      windowClass: 'center'
    modalInstance.result.then (rule) ->
      add_or_update_rule rule, ->
        $scope.test_run()
    , (reason) ->
      if reason == 'delete'
        $scope.test_run()
    return
  $scope.show_rule = (entry) ->
    if entry && entry.rule && entry.rule.action == "copy"
      true
    else
      false
  $scope.kind = (entry) ->
    kind_display(entry.rule.kind)

  $scope.dst_folder = (entry) ->
    dst_folder(entry)

  reset = ->
    $scope.show_result = false
    $scope.transfers = []
    $scope.running = []
    $scope.show_run = false
    $scope.show_test = false
    $scope.show_message = false

  $scope.actions = maid_actions
  $scope.kinds = maid_kinds
  reset()
]

maidControllers.controller 'RulesCtrl', ['$scope', '$modal', ($scope, $modal) ->
  refresh_rules = ->
    load_rules $scope, (rules) ->
      $scope.rules = rules
      $scope.$apply()

  $scope.edit_rule = (rule) ->
    $scope.entry = {rule:angular.copy(rule)}
    modalInstance = $modal.open
      templateUrl: 'edit_rule_modal.html'
      controller: 'ModalCtrl'
      size: 'lg'
      scope: $scope
      backdrop: 'static'
      windowClass: 'center'
      # resolve:
      #   rule: ->
      #     console.log $scope.rule
      #     $scope.rule
      #   test: ->
      #     'hello'
    modalInstance.result.then (rule) ->
      add_or_update_rule rule, ->
        refresh_rules()
    , (reason) ->
      if reason == 'delete'
        refresh_rules()
    return

  $scope.up_rule = (rule) ->
    prev_rule = find_prev_rule($scope.rules, rule)
    swap_rule(prev_rule, rule)
    add_or_update_rule prev_rule, ->
      add_or_update_rule rule, ->
        refresh_rules()

  refresh_rules()
]

is_image = (file) ->
  ext(file).match(/jpg/)

process_image = (path) ->

maidControllers.controller 'ImagesCtrl', ['$scope', ($scope) ->
  $scope.scan_folder = "/"
  $scope.scan = ->
    $scope.process_image_folder($scope.scan_folder)
  $scope.stop = ->
    $scope.stopped = true
  $scope.process_image_folder = (folder) ->
    for entry in dir_entry(folder)
      if $scope.stopped
        break
      if entry[0] != '.'
        path = Path.join(folder, entry)
        if exists(path)
          if is_dir(path)
            $scope.process_image_folder(path)
          else if is_image(entry)
            process_image(path)
          else
            console.log ext(entry)

]

maidControllers.controller 'SettingsCtrl', ['$scope', ($scope) ->
  load_settings (settings) ->
    $scope.settings = settings
    $scope.$apply()

  $scope.save = ->
    if settings._id
      settings_db.put settings, (err, resp) ->
    else
      settings_db.post settings, (err, resp) ->
]

maidControllers.controller 'ModalCtrl', ['$scope', '$modalInstance', ($scope, $modalInstance) ->
  $scope.title = ->
    if $scope.entry.rule._id
      "Edit Rule #{$scope.entry.rule.order}"
    else
      "Add New Rule"
  $scope.ok = ->
    $modalInstance.close($scope.entry.rule)

  $scope.insert = ->
    # add original rule as new rule
    $scope.original_rule._id = null
    $scope.original_rule._rev = null
    add_or_update_rule($scope.original_rule)

    $modalInstance.close($scope.entry.rule)

  $scope.cancel = ->
    $modalInstance.dismiss('cancel')

  $scope.delete = ->
    db.remove $scope.entry.rule, (err, response) ->
      $modalInstance.dismiss('delete')

  $scope.show_rule = ->
    $scope.entry.rule.action == "copy"
  $scope.renamed = ->
    renamed($scope.entry.rule, $scope.entry.name, $scope.entry.folder, $scope.entry.rule.rename)

  $scope.kind = ->
    kind_display($scope.entry.rule.kind)

  $scope.help_message = ->
    $scope.name_error = ''
    $scope.kind_error = ''
    if $scope.entry.rule.pattern == '' && $scope.entry.rule.ext == ''
      $scope.name_error = 'has-error'
      'Name Pattern or Ext Pattern is required.'
    else if $scope.entry.name && !match_rule($scope.entry.rule, $scope.entry.name, $scope.entry.folder)
      $scope.name_error = 'has-error'
      'Pattern does not match.'
    else if $scope.entry.rule.action == 'copy'
      if !$scope.entry.rule.kind
        $scope.kind_error = 'has-error'
        'When copy, kind should be set.'
      else if $scope.entry.rule.name
        dst_f = dst_folder($scope.entry)
        if contains(dst_f, ':')
          "Folder name can not contain ':'. #{dst_f}"
        else
          folder = folder_for_rule($scope.entry.rule)
          if !exists(Path.join(folder, dst_f))
            $scope.folder_error = "has-warning"
            "Folder '#{dst_folder($scope.entry)}' does not exist. It will be created."
          else
            $scope.folder_error = ''
            ''
      else
        ''
    else
      ''

  $scope.file_name = ->
    if $scope.entry.rule.include_folder
      Path.join(last_path($scope.entry.folder), $scope.entry.name)
    else
      $scope.entry.name

  $scope.dst_folder = ->
    dst_folder($scope.entry)

  $scope.actions = maid_actions
  $scope.kinds = maid_kinds
  $scope.original_rule = angular.copy($scope.entry.rule)
]
