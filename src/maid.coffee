maidApp = angular.module('maid', ['ngRoute', 'maidControllers']);

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

maidApp.directive 'dropdown', ['$timeout', ($timeout) ->
  restrict: "EA",
  replace: true,
  scope:
    ngModel: '=',
    data: '='
  template: '<div class="ui compact selection dropdown"><input type="hidden" name="id"><div class="default text">Select</div><i class="dropdown icon"></i><div class="menu"><div class="item" ng-repeat="item in data" data-value="{{item.value}}">{{item.label}}</div></div></div>',
  link: (scope, elem, attr) ->
    $timeout ->
      elem.dropdown
        onChange: (newValue) ->
          scope.$apply (scope) ->
            scope.ngModel = newValue
    scope.$watch "ngModel", (newValue) ->
      $timeout ->
        elem.dropdown('set selected', newValue)
]

maidControllers = angular.module('maidControllers', []);

maidControllers.controller 'MenuCtrl', ['$scope', '$route', ($scope, $route) ->
  $scope.active_class = (me) ->
    if $route.current and $route.current.templateUrl and me == $route.current.templateUrl[0..-6]
      "active"
    else
      ""
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

# db.allDocs({include_docs: true}, (err, response) ->
#   for row in response.rows
#     db.remove(row.doc, (err, doc) ->
#       console.log 'remove'
#       console.log err
#       console.log doc
#     )
# )

tvshow_folder = '/Volumes/Raid3/thetvdb'
rule_order = 1

all_rules = (scope, cb) ->
  scope.rules = []
  db.allDocs {include_docs: true}, (err, response) ->
    for row in response.rows
      if row.doc.order > rule_order
        rule_order = row.doc.order
      scope.rules.push(row.doc)
    cb()

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
  new RegExp(str, option)

whole_regexp = (str) ->
  regexp("^#{str}$")

match_rule = (rule, filename) ->
  rule && rule.ext && ext(filename).match(whole_regexp(rule.ext)) &&
  rule.pattern && filename.match(regexp(rule.pattern))

apply_rules = (file, rules) ->
  for rule in rules
    if match_rule(rule, file)
      return rule
  null

add_or_update_rule = (rule) ->
  if !rule._id
    rule_order += 1
    rule.order = rule_order
    db.post rule, (err, response) ->
      console.log 'add_rule', err, response
  else
    db.put rule, (err, response) ->
      console.log 'update_rule', err, response

maid_actions = ->
  [
    { label: 'Ignore', value: 'ignore' },
    { label: 'Copy', value: 'copy' },
    { label: 'Unrar', value: 'unrar' },
  ]

maid_kinds = ->
  [
    { label: 'TV Show', value: 'tvshow' },
    { label: 'Movie', value: 'movie' },
    { label: 'Porn', value: 'porn' },
  ]

renamed = (rule, file) ->
  if rule && rule.pattern && rule.rename && file
    basename(file).replace(regexp(rule.pattern), rule.rename) + "." + ext(file)
  else
    file

process_file = (file, rules, files, folder) ->
  rule = apply_rules(file, rules)
  if rule
    files.push({name: file, rule: rule, folder: folder, renamed: renamed(rule, file)})
    true
  else
    files.push({name: file, rule: {}})
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
  $scope.running.push "#{cmd} #{args}"
  spawn cmd, args

process_transfers = (transfers, $scope, nth) ->
  i = 0
  for transfer in transfers
    for file in transfer.files
      if file.rule.action == 'copy'
        if i == nth
          src = Path.join(file.folder, file.name)
          dst = Path.join(tvshow_folder, file.rule.name, file.renamed)
          cmd = spawn_log "cp", [src, dst], $scope
          $scope.$apply()
          cmd.on 'close', (code) ->
            if code == 0
              process_transfers transfers, $scope, nth + 1
          cmd.stdout.on 'data', (data) ->
            $scope.running.push data.toString()
          cmd.stderr.on 'data', (data) ->
            $scope.running.push data.toString()
          # console.log 'return'
          return
        i += 1
      else if file.rule.action == undefined
        $scope.running.push 'Done'
        $scope.$apply()
        return
    # if we're here, it means we processed all files in the transfer
    # but this loop is called many times, we execute it once with condition
    if i == nth
      exec_log "/usr/local/bin/transmission-remote -t #{transfer.tid} --remove", $scope
      if transfer.files[0].rule.action != 'remove'
        spawn_log "rm", ['-rf', transfer.path], $scope
      # console.log i, nth
      # console.log "transmission-remote -t #{transfer.tid} --remove"
      # console.log "rm", ['-rf', transfer.path]

maidControllers.controller 'HomeCtrl', ['$scope', '$timeout', ($scope, $timeout) ->
  $scope.test_run = ->
    all_rules $scope, ->
      $scope.transfers = process_transmission $scope.rules
      $scope.show_result = true
      $scope.running = []
      if $scope.transfers.length > 0
        $scope.show_run = true
      else
        $scope.show_run = false
      $scope.$apply()
      # myexec 'transmission-remote --list', (error, stdout, stderr) ->
      #   transfers = []
      #   for line in stdout.split("\n")
      #     tid = line[0 .. 4]
      #     name = line[70 .. -1]
      #     status = line[57 .. 69].trim()
      #     if status == "Finished"
      #       myexec "transmission-remote -t #{tid} --info", (error, stdout, stderr) ->
      #         for info in stdout.split("\n")
      #           if info[0 .. 11] == "  Location: "
      #             location = info[12 .. -1]
      #             files = []
      #             if is_dir(location, name)
      #               for file in dir_entry(location, name)
      #                 rule = apply_rules(file, $scope.rules)
      #                 if rule
      #                   files.push({type:"success", name: file, rule: rule})
      #                 else
      #                   files.push({type:"error", name: file, rule: {}})
      #                   break
      #             else
      #               files.push({type:"success", name: name, rule: {}})
      #             transfers.push {tid: tid, transfer: name, files: files, status: status}
      #             break
            
      #   $scope.transfers = transfers
      #   $scope.show_result = true
      #   $scope.$apply()
  $scope.run = ->
    $scope.running = []
    $timeout ->
      process_transfers($scope.transfers, $scope, 0)
  $scope.result_class = (file) ->
    if file.rule
      switch file.rule.action
        when "copy" then "positive"
        when "ignore" then ""
        when "unrar" then "positive"
        else "negative"
    else  
      "negative"
  $scope.edit_rule = (entry) ->
    $scope.entry = entry
    if !$scope.entry.rule.action
      $scope.entry.rule.action = 'ignore'
      $scope.entry.rule.pattern = '.+'
    # $scope.rule = angular.copy(file.rule)
    # $scope.rule = entry.rule
    # if !$scope.rule._id
    #   $scope.rule = {pattern: "", action: "ignore", kind: "tvshow"}
    # $scope.example = entry.name
    # $scope.dest = renamed($scope.rule, $scope.example)
    $scope.show_error = false
    $scope.dialog.modal('show')
    return
  $scope.done_rule = ->
    add_or_update_rule($scope.entry.rule)
    $scope.dialog.modal('hide')
    reset()
    return
  $scope.match_class = ->
    if $scope.entry && match_rule($scope.entry.rule, $scope.entry.name)
      "green"
    else
      "red"
  $scope.show_rule = (entry) ->
    if entry && entry.rule && entry.rule.action == "copy"
      true
    else
      false
  $scope.renamed = (entry) ->
    if entry
      renamed(entry.rule, entry.name)
  reset = ->
    $scope.show_result = false
    $scope.transfers = []
    $scope.running = []
    $scope.show_run = false
  $scope.dialog = $('#home_edit.ui.modal')
  $scope.dialog.modal()
  $('.menu.item').tab()
  $scope.actions = maid_actions();
  $scope.kinds = maid_kinds();
  reset()
]

maidControllers.controller 'TransferCtrl', ['$scope', '$http', ($scope, $http) ->
  $('.menu .item').tab()
]

maidControllers.controller 'RulesCtrl', ['$scope', ($scope) ->
  $scope.edit_rule = (rule) ->
    console.log rule
    $scope.dialog.modal 'show'
    $scope.entry.rule = rule
    return
  $scope.show_rule = (entry) ->
    if entry && entry.rule && entry.rule.action == "copy"
      true
    else
      false
  $scope.delete_rule = ->
    db.remove $scope.entry.rule, (err, response) ->
      $scope.dialog.modal 'hide'
    
  all_rules($scope, ->
    $scope.$apply())
  $scope.actions = maid_actions();
  $scope.kinds = maid_kinds();
  $scope.dialog = $('#rules_edit.ui.modal')
  $scope.entry = {rule: {}}
  $scope.dialog.modal()
  # $('.menu.item').tab()
]

maidControllers.controller 'SettingsCtrl', ['$scope', '$http', ($scope, $http) ->
  $('.menu .item').tab()
]