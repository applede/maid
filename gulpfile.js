var gulp = require('gulp');
var babel = require('gulp-babel');
var electron = require('gulp-electron');
// var gulp_atom = require('gulp-atom');
// var atomshell = require('gulp-atom-shell');
var shell = require('gulp-shell');
var plumber = require('gulp-plumber');
// var react = require('gulp-react');
var packageJson = require('./src/package.json');

var ELECTRON_VERSION = 'v0.26.0';
var PLATFORM = 'darwin-x64';
var COPY_FILES = ['src/*.html', 'src/package.json', 'src/*.css'];
// var JSX_FILES = 'src/*.jsx';
var JS_FILES = 'src/*.js';
var DEST = `release/${ELECTRON_VERSION}/${PLATFORM}/Maid.app/Contents/Resources/app`;
// var DEST = 'build';

// gulp.task('atom', function() {
//   return gulp_atom({
//         srcPath: './src',
//         releasePath: './release',
//         cachePath: './cache',
//         version: ELECTRON_VERSION,
//         rebuild: false,
//         platforms: [PLATFORM]
//     });
// });

gulp.task('electron', function() {
    gulp.src('')
    .pipe(electron({
        src: './src',
        packageJson: packageJson,
        release: './release',
        cache: './cache',
        version: ELECTRON_VERSION,
        rebuild: false,
        platforms: [PLATFORM]
    }))
    .pipe(gulp.dest(''));
});

// gulp.task('electron', function () {
//   return gulp.src('src/**')
//     .pipe(atomshell({
//       version: ELECTRON_VERSION,
//       platform: 'darwin'
//     }))
//     .pipe(atomshell.zfsdest('build.zip'))
//     .pipe(shell(['rm -rf build', 'open build.zip']));
// });

gulp.task('copy', function () {
  return gulp.src(COPY_FILES)
    .pipe(gulp.dest(DEST));
});

// gulp.task('jsx', function () {
//   return gulp.src(JSX_FILES)
//     .pipe(plumber())
//     .pipe(react({ harmony: true, stripTypes: true, nonStrictEs6module: true }))
//     .pipe(gulp.dest(DEST));
// });

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
