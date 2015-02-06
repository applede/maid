gulp = require 'gulp'
coffee = require 'gulp-coffee'
slim = require 'gulp-slim'
jade = require 'gulp-jade'
plumber = require 'gulp-plumber'
shell = require 'gulp-shell'
# atomshell = require('gulp-atom-shell')
# downloadAtomShell = require('gulp-download-atom-shell')
COFFEE = 'src/*.coffee'
JSON = 'src/package.json'
SLIM = 'views/*.slim'
JADE = 'views/*.jade'
CSS = 'views/*.css'
HTML = 'views/*.html'
ICON = 'resource/maid.icns'
DEST = 'Maid.app/Contents/Resources/app'
DEST_VIEWS = DEST + '/views'
DEST_ICON = DEST + '/..'

gulp.task 'coffee', ->
  gulp.src(COFFEE)
      .pipe(plumber())
      .pipe(coffee())
      .pipe(gulp.dest(DEST))

gulp.task 'json', ->
  gulp.src(JSON)
      .pipe(gulp.dest(DEST))

gulp.task 'icon', ->
  gulp.src(ICON)
      .pipe(gulp.dest(DEST_ICON))

gulp.task 'slim', ->
  gulp.src(SLIM)
      .pipe(slim({ pretty: true }))
      .pipe(gulp.dest(DEST_VIEWS))

gulp.task 'jade', ->
  gulp.src(JADE)
      .pipe(plumber())
      .pipe(jade({ pretty: true }))
      .pipe(gulp.dest(DEST_VIEWS))

gulp.task 'css', ->
  gulp.src(CSS)
      .pipe(gulp.dest(DEST_VIEWS))

gulp.task 'html', ->
  gulp.src(HTML)
      .pipe(gulp.dest(DEST_VIEWS))

gulp.task 'build', ['coffee', 'jade', 'css', 'json', 'icon'], ->
  gulp.src("")
      .pipe(shell(["bower install"]))
      .pipe(shell(["cd #{DEST};npm install"]))
  # gulp.src('')
  #     .pipe(atomshell({
  #       version: '0.21.1',
  #       productName: 'Maid',
  #       productVersion: '0.0.1',
  #       platform: 'darwin'
  #     }))

gulp.task 'default', ['build'], ->
  gulp.watch(COFFEE, ['coffee'])
  gulp.watch(JSON, ['json'])
  gulp.watch(CSS, ['css'])
  gulp.watch(SLIM, ['slim'])
  gulp.watch(JADE, ['jade'])
  gulp.watch(HTML, ['html'])