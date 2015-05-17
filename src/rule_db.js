import {join, last_path, ext, basename, normalize, whole_word} from './util';

// rule database
class Rules {
  constructor() {
    this.rules = [];
    this.max_order = 0;
    this.db = new window.PouchDB('rules');
  }

  // load rules then call back
  load(callback) {
    this.db.allDocs({ include_docs: true }, (err, response) => {
      this.rules = response.rows.map(row => { return row.doc; });
      if (this.rules.length > 0) {
        this.rules.sort(function(a, b) { return a.order - b.order; });
        this.max_order = this.rules[this.rules.length - 1].order;
      }
      callback(this.rules);
    });
  }

  // next order number
  next_order() {
    this.max_order += 1;
    return this.max_order;
  }

  // saves a rule then call back
  save(rule, callback) {
    if (rule.order) {
      this.db.put(rule, function(err, res) {
        if (callback) {
          callback();
        }
      });
    } else {
      rule.order = this.next_order();
      this.db.post(rule, function(err, res) {
        if (callback) {
          callback();
        }
      });
    }
  }

  save_as_new(rule, callback) {
    var new_rule = {};
    for (var key in rule) {
      if (key !== '_id' && key !== '_rev' && key !== 'order') {
        new_rule[key] = rule[key];
      }
    }
    this.save(new_rule, callback);
  }

  delete(rule, callback) {
    this.db.remove(rule, callback);
  }

  // checks if a rule matches folder+filename
  does_match(rule, folder, filename) {
    if (rule.include_folder) {
      filename = join(last_path(folder), filename);
    }
    return ext(filename).match(whole_word(rule.ext)) &&
      basename(normalize(filename)).match(whole_word(normalize(rule.pattern)));
  }

  // find a rule which matches the folder and the file name.
  // if not found, returns no match rule.
  find_matching(folder, filename) {
    for (let rule of this.rules) {
      if (this.does_match(rule, folder, filename)) {
        return rule;
      }
    }
    return { action: 'no match', folder: 'Unknown' };
  }
}

var rule_db = new Rules();

export default rule_db;
