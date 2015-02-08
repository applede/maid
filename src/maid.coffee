maidApp = angular.module('maid', ['ngRoute', 'maidControllers', 'ui.bootstrap']);

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
    .when '/settings',
      templateUrl: 'settings.html',
      controller: 'SettingsCtrl'
    .otherwise
      redirectTo: '/home'
]

maidControllers = angular.module('maidControllers', []);

maidControllers.controller 'MenuCtrl', ['$scope', '$location', ($scope, $location) ->
  $scope.is_active = (loc) ->
    loc == $location.path()
]

remote = require 'remote'
ipc = require 'ipc'
exec = require('child_process').exec
# myexec = (cmd, callback) ->
#   exec cmd, {env: {PATH: "/usr/local/bin:/usr/bin:/bin"}}, callback
fs = require 'fs'
pouchdb = require 'pouchdb'
# shell = remote.require 'shelljs'
spawn = require('child_process').spawn
spawn_sync = require('child_process').spawnSync
Path = require 'path'

db = new pouchdb('rules', {adapter: 'idb'})

tvshow_folder = '/Volumes/Raid3/thetvdb'
porn_folder = '/Users/apple/mount/Raid2/porn'
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

exists = (path) ->
  fs.existsSync(path)

is_dir = (path) ->
  fs.statSync(path).isDirectory()

dir_entry = (path) ->
  fs.readdirSync(path)

basename = (filename) ->
  compo = filename.split('.')
  if compo.length == 1
    filename
  else
    compo.pop()
    compo.join('.')

ext = (filename) ->
  compo = filename.split('.')
  if compo.length == 1
    ""
  else
    compo.pop()

regexp = (str) ->
  option = if str.match(/[A-Z]/) then "" else "i"
  try
    r = new RegExp(str, option)
  catch e
    r = new RegExp(".+")
  r

whole_regexp = (str) ->
  regexp("^#{str}$")

match_rule = (rule, filename) ->
  rule && ext(filename).match(whole_regexp(rule.ext)) &&
  rule.pattern && basename(filename).match(regexp(rule.pattern))

apply_rules = (file, rules) ->
  for rule in rules
    if match_rule(rule, file)
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
  str[0].toUpperCase() + str[1 ..].toLowerCase()

capitalize_each = (str) ->
  (capitalize(s) for s in str.split(' ')).join(' ')

renamed = (rule, file) ->
  if rule && rule.pattern && rule.rename && file
    options = []
    rename = rule.rename
    m = basename(file).match(regexp(rule.pattern))
    if m
      for i in [1 .. 9]
        index = rename.indexOf("$#{i}")
        if index == -1
          break
        end = index + 2
        sub = m[i]
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
          else
            break
          end += 2
        rename = rename.replace(rename[index ... end], sub)
    basename(file).replace(regexp(rule.pattern), rename) + "." + ext(file)
  else
    file

process_file = (file, rules, files, folder) ->
  rule = apply_rules(file, rules)
  if rule
    files.push({name: file, rule: rule, folder: folder, renamed: renamed(rule, file)})
    true
  else
    files.push({name: file, rule: {action: "no match"}})
    false

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
          files = []
          if exists(path)
            if is_dir(path)
              for file in dir_entry(path)
                if ret = !process_file(file, rules, files, path)
                  break
            else
              ret = !process_file(name, rules, files, location)
            transfers.push {tid: tid, transfer: name, files: files, path: path, status: status}
          else
            transfers.push {tid: tid, transfer: name, files: [{name: 'Not exists', rule: {action: 'remove'}}], path: path, status: status}
          if ret
            return transfers
  transfers

exec_log = (cmd, $scope) ->
  $scope.running.push cmd
  exec(cmd)

spawn_log = (cmd, args, $scope) ->
  if cmd != "echo"
    $scope.running.push "#{cmd} #{args.join(' ')}"
  spawn cmd, args

spawn_sync_log = (cmd, args, $scope) ->
  $scope.running.push "#{cmd} #{args.join(' ')}"
  spawn_sync cmd, args

mkdir_if_not_exist = (path, $scope) ->
  compo = path.split('/')
  compo.pop()
  path = compo.join('/')
  if !exists(path)
    spawn_sync_log('mkdir', ['-p', path], $scope)

file_size = (path) ->
  fs.statSync(path).size

pretty_size = (x) ->
  x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")

copy_if_bigger = (src, dst, $scope) ->
  if exists(dst)
    dst_size = file_size(dst)
    src_size = file_size(src)
    if dst_size >= src_size
      return spawn_log 'echo', ["skip dst (#{pretty_size(dst_size)}) >= src (#{pretty_size(src_size)})"], $scope
    else
      $scope.running.push "overwrite: dst (#{pretty_size(dst_size)}) < src (#{pretty_size(src_size)})"
  else
    mkdir_if_not_exist(dst, $scope)
  spawn_log 'cp', [src, dst], $scope

process_transfers = (transfers, $scope, nth) ->
  i = 0
  for transfer in transfers
    if i == nth
      $scope.running.push "Processing #{transfer.transfer}"
    for file in transfer.files
      if file.rule.action == 'copy'
        if i == nth
          src = Path.join(file.folder, file.name)
          if file.rule.kind == 'porn'
            dst_folder = porn_folder
          else if file.rule.kind == 'tvshow'
            dst_folder = tvshow_folder
          else if file.rule.kind == 'movie'
            dst_folder = movie_folder
          else
            return
          dst = Path.join(dst_folder, file.rule.name, file.renamed)
          cmd = copy_if_bigger(src, dst, $scope)
          $scope.$apply()
          cmd.on 'close', (code) ->
            if code == 0
              process_transfers transfers, $scope, nth + 1
          cmd.stdout.on 'data', (data) ->
            $scope.running.push data.toString()
          cmd.stderr.on 'data', (data) ->
            $scope.running.push data.toString()
          return
        i += 1
      else if file.rule.action == 'no match'
        $scope.running.pop()
        $scope.running.push 'Done'
        $scope.$apply()
        return
    # if we're here, it means we processed all files in the transfer
    # but this loop is called many times, we execute it once with condition
    if i == nth
      exec_log "/usr/local/bin/transmission-remote -t #{transfer.tid} --remove", $scope
      if transfer.files[0].rule.action != 'remove'
        spawn_log "rm", ['-rf', transfer.path], $scope

maidControllers.controller 'HomeCtrl', ['$scope', '$timeout', '$modal', ($scope, $timeout, $modal) ->
  $scope.test_run = ->
    load_rules $scope, (rules) ->
      $scope.transfers = process_transmission rules
      $scope.show_result = true
      $scope.running = []
      if $scope.transfers.length > 1
        # one successful entry + one failed entry, so at least 2
        $scope.show_run = true
      else
        $scope.show_run = false
      $scope.$apply()
  $scope.run = ->
    $scope.running = []
    $timeout ->
      process_transfers($scope.transfers, $scope, 0)
  $scope.result_class = (file) ->
    if file.rule
      switch file.rule.action
        when "copy" then "success"
        when "ignore" then ""
        when "unrar" then "success"
        else "danger"
    else  
      "danger"
  $scope.edit_rule = (entry) ->
    # $scope.entry = entry
    # $scope.show_error = false
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
    return
  $scope.show_rule = (entry) ->
    if entry && entry.rule && entry.rule.action == "copy"
      true
    else
      false
  # $scope.renamed = (entry) ->
  #   if entry
  #     renamed(entry.rule, entry.name)
  $scope.kind = (entry) ->
    kind_display(entry.rule.kind)
  $scope.cmd_class = (cmd) ->
    if cmd.match(/^Processing/)
      "info"
    else if cmd.match(/^Done/)
      "success"

  reset = ->
    $scope.show_result = false
    $scope.transfers = []
    $scope.running = []
    $scope.show_run = false
    $scope.show_error = false
  $scope.actions = maid_actions
  $scope.kinds = maid_kinds
  reset()
]

maidControllers.controller 'TransferCtrl', ['$scope', '$http', ($scope, $http) ->
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
    return
  $scope.delete_rule = ->
    db.remove $scope.entry.rule, (err, response) ->
      $scope.dialog.modal 'hide'

  refresh_rules()
]

maidControllers.controller 'SettingsCtrl', ['$scope', '$http', ($scope, $http) ->
]

maidControllers.controller 'ModalCtrl', ['$scope', '$modalInstance', '$timeout', ($scope, $modalInstance, $timeout) ->
  $scope.title = ->
    if $scope.entry.rule.action == "no match"
      "Add"
    else
      "Edit"
  $scope.ok = ->
      $modalInstance.close($scope.entry.rule)

  $scope.cancel = ->
    $modalInstance.dismiss('cancel')
  $scope.show_rule = ->
    $scope.entry.rule.action == "copy"
  $scope.renamed = ->
    renamed($scope.entry.rule, $scope.entry.name)

  $scope.kind = ->
    kind_display($scope.entry.rule.kind)

  $scope.error_message = ->
    message =
      if $scope.entry.rule.pattern == '' && $scope.entry.rule.ext == ''
        'Name Pattern or Ext Pattern is required'
      else if $scope.entry.name && !match_rule($scope.entry.rule, $scope.entry.name)
        'Pattern does not match'
      else if $scope.entry.rule.action == 'copy'
        if !$scope.entry.rule.kind
          'When copy, kind should be set'
        else if $scope.entry.rule.name && !exists(Path.join(porn_folder, $scope.entry.rule.name))
          "Folder #{$scope.entry.rule.name} does not exist"
        else
          ''
      else
        ''
    if message
      $scope.error_class = "alert-danger"
    else
      $scope.error_class = "alert-success"

    message
  $scope.actions = maid_actions
  $scope.kinds = maid_kinds
]
