var gulp = require('gulp');
var babel = require('gulp-babel');
var atomshell = require('gulp-atom-shell');
var shell = require('gulp-shell');
var plumber = require('gulp-plumber');

var ELECTRON_VERSION = '0.27.1';
var COPY_FILES = ['src/*.html', 'src/package.json', 'src/*.css'];
var JS_FILES = 'src/*.js';
var DEST = `build/Maid.app/Contents/Resources/app`;

gulp.task('electron', function () {
  return gulp.src('src/**')
    .pipe(atomshell({
      version: ELECTRON_VERSION,
      platform: 'darwin',
      darwinIcon: 'resource/maid.icns'
    }))
    .pipe(atomshell.zfsdest('build.zip'))
    .pipe(shell(['rm -rf build', 'open build.zip']));
});

gulp.task('copy', function () {
  return gulp.src(COPY_FILES)
    .pipe(gulp.dest(DEST));
});

gulp.task('babel', function () {
  return gulp.src(JS_FILES)
    .pipe(plumber())
    .pipe(babel())
    .pipe(gulp.dest(DEST));
});

gulp.task('build', function () {
  return gulp.src('')
    .pipe(shell(['bower install']))
    .pipe(shell(['cd ' + DEST + ';npm install']));
});

gulp.task('default', ['build', 'copy', 'babel'], function () {
  gulp.watch(COPY_FILES, ['copy']);
  gulp.watch(JS_FILES, ['babel']);
});
