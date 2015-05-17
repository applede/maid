import React from 'react';
import rule_db from './rule_db';
import settings from './settings';
import {is_regexp, join, last_path, basename, normalize, whole_word, ext, case_reg_exp,
        copy, exists, update} from './util';

function capitalize(str) {
  if (str) {
    if (str[0] === '(') {
      return str[0] + str[1].toUpperCase() + str.slice(2).toLowerCase();
    } else if (str === 'II') {
      return str;
    } else {
      return str[0].toUpperCase() + str.slice(1).toLowerCase();
    }
  }
}

function capitalize_each(str) {
  if (str) {
    let words = [];
    let splits = str.split(' ');
    let delim = ' ';
    if (splits.length === 1) {
      splits = str.split('-');
      delim = '-';
    }
    for (let s of splits) {
      words.push(capitalize(s));
    }
    return words.join(delim);
  }
}

// convert string to int
function get_int(str, index) {
  var orig = index;
  while (str[index] >= '0' && str[index] <= '9') {
    index++;
  }
  return { value: parseInt(str.slice(orig)), len: index - orig };
}

// renamed file name
function renamed_str(rule, folder, file, rename, no_ext) {
  if (rule && rule.pattern && file && rename) {
    var file_name;
    if (rule.include_folder) {
      file_name = join(last_path(folder), file);
    } else {
      file_name = file;
    }
    var m = basename(normalize(file_name)).match(whole_word(normalize(rule.pattern)));
    if (m) {
      for (var i = 0; i <= 9; i++) {
        var index = rename.indexOf(`$${i}`);
        if (index === -1) {
          continue;
        }
        var end = index + 2;
        var sub = m[i] || '';
        for (;;) {
          var modifier = rename.slice(end, end + 2);
          if (modifier === ':c') {
            sub = capitalize(sub);
          } else if (modifier === ':C') {
            sub = capitalize_each(sub);
          } else if (modifier === ':.') {
            sub = sub.replace(/\./g, ' ');
          } else if (modifier === ':_') {
            sub = sub.replace(/_/g, ' ');
          } else if (modifier === ':-') {
            var r = get_int(rename, end + 2);
            sub = ('0' + (parseInt(sub) - r.value)).slice(-2);
            end += r.len;
          } else if (modifier === ':0') {
            sub = ('00' + sub).slice(-2);
          } else {
            break;
          }
          end += 2;
        }
        rename = rename.replace(rename.slice(index, end), sub);
      }
    }
    return basename(normalize(file_name)).replace(case_reg_exp(normalize(rule.pattern)), rename) +
      (no_ext ? '' : '.' + ext(file));
  } else {
    return file;
  }
}

export function dest_folder(rule, file) {
  if (is_regexp(rule.folder)) {
    return renamed_str(rule, file.folder, file.name, rule.folder, true);
  }
  return rule.folder;
}

export function renamed(rule, file) {
  return renamed_str(rule, file.folder, file.name, rule.rename);
}

// modal dialog for editing a rule
var EditRule = React.createClass({
  getInitialState() {
    return { rule: { pattern: '.+', ext: '', include_folder: false }};
  },
  componentDidMount() {
    var rule = this.props.file.rule;
    if (rule.action === 'no match') {
      rule.pattern = '.+';
      rule.ext = ext(this.props.file.name);
      rule.include_folder = false;
      rule.action = 'ignore';
      rule.kind = 'tvshow';
      rule.folder = '';
    }
    this.orig_rule = copy(rule);
    this.setState({ rule: rule });
  },
  title() {
    if (this.new_rule()) {
      return 'Edit Rule (New Rule)';
    } else {
      return `Edit Rule #${this.state.rule.order}`;
    }
  },
  new_rule() {
    return !this.state.rule._id;
  },
  file_name() {
    if (this.state.rule.include_folder) {
      return (
        <ol className='breadcrumb'>
          <li>{last_path(this.props.file.folder)}</li>
          <li>{this.props.file.name}</li>
        </ol>
      );
    } else {
      return (
        <ol className='breadcrumb'>
          <li>{this.props.file.name}</li>
        </ol>
      );
    }
  },
  dest_folder() {
    return dest_folder(this.state.rule, this.props.file);
  },
  // dst_folder() {
  //   if (is_regexp(this.state.rule.folder)) {
  //     return renamed(this.state.rule, this.props.file.folder, this.props.file.name,
  //       this.state.rule.folder, true);
  //   }
  //   return this.state.rule.folder;
  // },
  renamed() {
    return renamed_str(this.state.rule, this.props.file.folder, this.props.file.name,
      this.state.rule.rename);
  },
  valid_pattern() {
    if (rule_db.does_match(this.state.rule, this.props.file.folder, this.props.file.name)) {
      this.pattern_error = null;
      return null;
    }
    this.pattern_error = 'Pattern does not match.';
    return 'error';
  },
  valid_folder() {
    var location = settings.folder_for(this.state.rule.kind);
    var folder = this.dest_folder();
    if (folder === '') {
      this.folder_error = true;
      this.folder_error_message = 'Folder is empty.';
      return 'error';
    } else if (exists(join(location, folder))) {
      this.folder_error = false;
      this.folder_error_message = null;
      return null;
    } else {
      this.folder_error = false;
      this.folder_error_message = `Folder "${folder}" will be created.`;
      return 'warning';
    }
  },
  invalid_rule() {
    return this.pattern_error || this.folder_error;
  },
  message() {
    if (this.pattern_error) {
      return this.pattern_error;
    }
    if (this.folder_error_message) {
      return this.folder_error_message;
    }
    return '';
  },
  updateRule(some) {
    this.setState({ rule: update(this.state.rule, some) });
  },
  changePattern(event) {
    this.updateRule({ pattern: event.target.value });
  },
  changeExt(event) {
    this.updateRule({ ext: event.target.value });
  },
  changeAction(event) {
    if (event.target.value === 'ignore' || event.target.value === 'unrar') {
      this.folder_error = false;
      this.folder_error_message = null;
    }
    this.updateRule({ action: event.target.value });
  },
  changeIncludeFolder(event) {
    this.updateRule({ include_folder: this.refs.include_folder.getChecked() });
  },
  changeKind(event) {
    this.updateRule({ kind: event.target.value });
  },
  changeFolder(event) {
    this.updateRule({ folder: event.target.value });
  },
  changeRename(event) {
    this.updateRule({ rename: event.target.value });
  },
  close() {
    this.props.onRequestHide();
  },
  insert() {
    if (this.new_rule()) {
      this.update();
    } else {
      rule_db.save_as_new(this.orig_rule);
      this.update();
    }
  },
  update() {
    rule_db.save(this.state.rule);
    this.close();
    this.props.refresh();
  },
  render_dest_file() {
    if (this.state.rule.action === 'copy') {
      return (
        <Row>
          <Col mdOffset={1} md={1}>
            <span className='glyphicon glyphicon-arrow-down'></span>
          </Col>
          <Col md={12}>
            <ol className='breadcrumb'>
              <li>{this.dest_folder()}</li>
              <li>{this.renamed()}</li>
            </ol>
          </Col>
        </Row>
      );
    } else {
      return (
        <Row>
          <Col>&nbsp;</Col>
        </Row>
      );
    }
  },
  render_copy_rule() {
    if (this.state.rule.action === 'copy') {
      return (
        <Row>
          <Col md={2}>
            <Input type='select' label='Kind' value={this.state.rule.kind} onChange={this.changeKind}>
              <option value='tvshow'>TV Show</option>
              <option value='movie'>Movie</option>
              <option value='porn'>Porn</option>
            </Input>
          </Col>
          <Col md={4}>
            <Input type='text' label='Folder' value={this.state.rule.folder}
              bsStyle={this.valid_folder()} onChange={this.changeFolder}/>
          </Col>
          <Col md={6}>
            <Input type='text' label='Rename' value={this.state.rule.rename} onChange={this.changeRename}/>
          </Col>
        </Row>
      );
    } else {
      return (<Row></Row>);
    }
  },
  render() {
    return (
      <Modal bsStyle='primary' bsSize='large' title={this.title()} backdrop={false}
        onRequestHide={this.props.onRequestHide}>
        <div className='modal-body'>
          <Row>
            <Col md={12}>
              {this.file_name()}
            </Col>
          </Row>
          {this.render_dest_file()}
          <Row>
            <Col md={7}>
              <Input type='text' label='Name Pattern' value={this.state.rule.pattern}
                bsStyle={this.valid_pattern()} onChange={this.changePattern}/>
              <Input type='checkbox' label='Include folder name for pattern matching'
                onChange={this.changeIncludeFolder} ref='include_folder'
                value={this.state.rule.include_folder}/>
            </Col>
            <Col md={3}>
              <Input type='text' label='Ext Pattern' value={this.state.rule.ext}
                bsStyle={this.valid_pattern()} onChange={this.changeExt}/>
            </Col>
            <Col md={2}>
              <Input type='select' label='Action' ref='action' value={this.state.rule.action}
                onChange={this.changeAction}>
                <option value='ignore'>Ignore</option>
                <option value='copy'>Copy</option>
                <option value='unrar'>Unrar</option>
              </Input>
            </Col>
          </Row>
          {this.render_copy_rule()}
          <Row>
            <Col md={12}>
              {this.message()}
            </Col>
          </Row>
        </div>
        <div className='modal-footer'>
          <Button onClick={this.close}>Cancel</Button>
          <Button bsStyle='danger' disabled={this.new_rule()} onClick={this.delete}>Delete</Button>
          <Button bsStyle='success' disabled={this.new_rule()} onClick={this.update}>Update</Button>
          <Button bsStyle='primary' disabled={this.invalid_rule()} onClick={this.insert}>Insert New</Button>
        </div>
      </Modal>
    );
  }
});

export default EditRule;
