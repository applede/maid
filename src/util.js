import Path from 'path';
import Fs from 'fs';
import ChildProcess from 'child_process';
import Unorm from 'unorm';

export var spawn_sync = ChildProcess.spawnSync;
export var spawn = ChildProcess.spawn;

export function join(a, b) {
  return Path.join(a, b);
}

// return extension of filename
export function ext(filename) {
  return Path.extname(filename).slice(1);
}

// return basename of filename
export function basename(filename) {
  var compo = filename.split('.');
  if (compo.length === 1) {
    return filename;
  } else {
    compo.pop();
    return compo.join('.');
  }
}

// returns last path component
export function last_path(path) {
  return Path.basename(path);
}

// check if file exists
export function exists(path) {
  return Fs.existsSync(path);
}

// check if path is directory
export function is_dir(path) {
  return Fs.statSync(path).isDirectory();
}

// return entries in a directory
export function dir_entries(path) {
  return Fs.readdirSync(path);
}

// returns file size
export function file_size(path) {
  return Fs.statSync(path).size;
}

// mkdir if path does not exist
export function mkdir_if_not_exist(path) {
  path = Path.dirname(path);
  if (!exists(path)) {
    spawn_sync('mkdir', ['-p', path]);
  }
}

// resolve ~ to user home
function resolve_home(path) {
  return path.replace(/^~/, process.env.HOME);
}

// remove file
export function rm(path) {
  spawn_sync('rm', [resolve_home(path)]);
}

// return normalization form of canonical decomposition of utf-8 string
export function normalize(str) {
  return Unorm.nfd(str);
}

// is it a regular expression?
export function is_regexp(str) {
  return str && str.match(/\$[0-9]/);
}

// create regular expression from a string
export function case_reg_exp(str) {
  var option = '';
  if (!str.match(/[A-Z]/)) { option = 'i'; }
  var r;
  try {
    r = new RegExp(str, option);
  } catch (e) {
    r = new RegExp('^$');
  }
  return r;
}

// return regular expression matching entire string
export function whole_word(str) {
  return case_reg_exp(`^${str}$`);
}

// check if an array contains an element
export function contains(array, elem) {
  for (var e of array) {
    if (e === elem) {
      return true;
    }
  }
  return false;
}

// return last element of array
export function last_of(array) {
  return array[array.length - 1];
}

// append array2 to array1
export function append(array1, array2) {
  for (var e of array2) {
    array1.push(e);
  }
}

// shallow copy of obj
export function copy(obj) {
  var new_obj = {};
  for (var key in obj) {
    new_obj[key] = obj[key];
  }
  return new_obj;
}

// update some properties in obj
export function update(obj, some) {
  var new_obj = copy(obj);
  for (var key in some) {
    new_obj[key] = some[key];
  }
  return new_obj;
}
