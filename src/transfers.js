import React from 'react';
import TransferredFiles from './transferred_file';
import ExecResult from './exec_result';
import rule_db from './rule_db';
import {dest_folder, renamed} from './edit_rule';
import settings from './settings';
import {exists, is_dir, dir_entries, join, file_size, mkdir_if_not_exist, append, spawn_sync, spawn,
        copy, rm} from './util';

// returns list of file objects in the directory folder+name or file name.
// inside should be falsy
function files_in(folder, name, inside) {
  var path = join(folder, name);
  if (exists(path)) {
    if (is_dir(path)) {
      if (inside) {
        var files = [];
        dir_entries(path).forEach(file => {
          if (file[0] !== '.') {
            var sub_folder = join(name, file);
            append(files, files_in(folder, sub_folder, true));
          }
        });
        return files;
      } else {
        return files_in(path, '', true);
      }
    } else {
      return [{ folder: folder, name: name }];
    }
  } else {
    return [];
  }
}

// load finished transfer list from transmission
function finished_transfers() {
  var lines = spawn_sync('transmission-remote', ['--list']).stdout.toString();
  let transfers = [];
  for (var line of lines.split('\n')) {
    var tid = line.slice(0, 4).trim();
    var status = line.slice(57, 69).trim();
    var name = line.slice(70);
    if (status === 'Finished') {
      transfers.push({ tid: tid, status: status, name: name });
    }
  }
  return transfers;
}

// find files for each transfer
function find_files(transfers) {
  for (var transfer of transfers) {
    var infos = spawn_sync('transmission-remote', ['-t', transfer.tid, '--info']).stdout.toString();
    for (var info of infos.split('\n')) {
      if (info.slice(0, 12) === '  Location: ') {
        var location = info.slice(12);
        transfer.files = files_in(location, transfer.name);
        transfer.folder = join(location, transfer.name);
      }
    }
  }
  return transfers;
}

// find matching rules for each files
function find_rule_for(transfers) {
  for (var transfer of transfers) {
    for (var file of transfer.files) {
      file.rule = rule_db.find_matching(file.folder, file.name);
      file.dest = join(dest_folder(file.rule, file), renamed(file.rule, file));
    }
  }
  return transfers;
}

// copy file if src is bigger than dst
function copy_if_bigger(src, dst) {
  var result = { type: 'copy', src: src, dst: dst, src_size: 0, dst_size: 0, cur_size: 0 };
  if (exists(src)) {
    result.src_size = file_size(src);
  } else {
    return { type: 'error', message: `File not exists: ${src}` };
  }
  if (exists(dst)) {
    result.dst_size = file_size(dst);
    if (result.dst_size >= result.src_size) {
      result.type = 'skip';
      return result;
    }
    result.type = 'overwrite';
  } else {
    result.dst_size = 0;
    mkdir_if_not_exist(dst);
  }
  spawn('cp', [src, dst]);
  // if (cmd) {
  //   cmd.on('close', callback);
  // }
  return result;
}

// find ith file
function find_ith_file(transfers, ith) {
  var i = 0;
  for (var transfer of transfers) {
    for (var file of transfer.files) {
      if (i === ith) {
        return file;
      }
      i++;
    }
  }
  return null;
}

// check if transfer has unrar action
function has_unrar(transfer) {
  for (var file of transfer.files) {
    if (file.rule.action === 'unrar') {
      return true;
    }
  }
  return false;
}

// remove transfers
function remove_transfers(transfers) {
  for (var transfer of transfers) {
    if (!has_unrar(transfer)) {
      spawn_sync('transmission-remote', ['-t', transfer.tid, '--remove']);
      spawn_sync('rm', ['-rf', transfer.folder]);
    }
  }
}

// Finished transfers
var Transfers = React.createClass({
  // constructor(props) {
  //   super(props);
  //   this.state = { transfers: [], results: [], progress_result: null };
  // },
  getInitialState() {
    return { transfers: [], results: [], progress_result: null };
  },

  // redraw
  componentDidMount() {
    this.refresh();
  },

  refresh() {
    rule_db.load(() => {
      this.setState({
        transfers: find_rule_for(find_files(finished_transfers())),
        results: []
      });
    });
  },

  // update copy progress
  tick() {
    var result = copy(this.state.progress_result);
    result.cur_size = file_size(result.dst);
    this.setState({ progress_result: result });
    if (result.cur_size >= result.src_size) {
      this.copy_done();
    } else {
      setTimeout(this.tick, 100);
    }
  },

  // copy done.
  copy_done() {
    var result = copy(this.state.progress_result);
    result.cur_size = result.src_size;
    this.results.push(result);
    this.setState({ results: this.results, progress_result: null });
    this.ith++;
    this.process_ith();
  },

  unrar(src, dst, callback) {
    var result = { type: 'unrar', src: src, dst: dst, output: [], progress: 0 };
    var cmd = spawn('unrar', ['e', '-o+', src, dst]);
    if (cmd) {
      cmd.on('close', () => {
        result.progress = 100;
        this.setState({ progress_result: result });
        callback();
      });
      cmd.stdout.on('data', (data) => {
        for (var s of data.toString().split('\n')) {
          var m = s.match(/ (\d+)%/);
          if (m) {
            result.progress = parseInt(m[1]);
          } else {
            result.output.push(s);
          }
          this.setState({ progress_result: result });
        }
      });
    }
    return result;
  },

  // process ith item in transfers list
  process_ith() {
    var file = find_ith_file(this.state.transfers, this.ith);
    if (file) {
      if (file.rule.action === 'copy') {
        let src = join(file.folder, file.name);
        var dst = join(settings.folder_for(file.rule.kind), file.dest);
        let result = copy_if_bigger(src, dst);
        this.setState({ progress_result: result });
        if (result.type === 'skip') {
          setTimeout(this.copy_done, 100);
        } else {
          setTimeout(this.tick, 100);
        }
      } else if (file.rule.action === 'unrar') {
        let src = join(file.folder, file.name);
        let result = this.unrar(src, file.folder, () => {
          this.copy_done();
          rm(src);
        });
        this.setState({ progress_result: result });
      } else {
        this.ith++;
        this.process_ith();
      }
    } else {
      remove_transfers(this.state.transfers);
    }
  },

  // user pressed execute button
  execute() {
    this.results = [];
    this.ith = 0;
    this.process_ith();
  },

  componentDidUpdate() {
    if (this.state.progress_result) {
      var node = this.getDOMNode().parentNode.parentNode;
      node.scrollTop = node.scrollHeight;
    }
  },

  render() {
    // var refresh = this.refresh;
    var transfers = this.state.transfers.map((transfer) => {
      // var files = transfer.files.map(function(file) {
      //   return (
      //     <TransferredFile key={file.name} file={file} refresh={refresh}></TransferredFile>
      //   );
      // });
      return (
        <Table key={transfer.tid} bordered>
          <thead>
            <tr className='active'>
              <th colSpan='3'>{transfer.name}</th>
            </tr>
          </thead>
          <TransferredFiles files={transfer.files} refresh={this.refresh}></TransferredFiles>
        </Table>
      );
      // <tbody>
      // </tbody>
    });
    var execute_button = '';
    if (this.state.transfers.length > 0) {
      execute_button = <Button onClick={this.execute}>Execute</Button>;
    } else {
      execute_button = <Alert>Nothing</Alert>;
    }
    var key = 1;
    var results = this.state.results.map((result) => {
      return (
        <ExecResult key={key++} result={result}></ExecResult>
      );
    });
    var progress_result = '';
    var refresh_button = '';
    if (this.state.progress_result) {
      progress_result = <ExecResult key={key++} result={this.state.progress_result}></ExecResult>;
    } else {
      refresh_button = <Button onClick={this.refresh}>Refresh</Button>;
    }
    return (
      <div className='container' ref='results'>
        <h4>Finished Transfers</h4>
        {transfers}
        <p></p>
        {execute_button}
        <p></p>
        {results}
        {progress_result}
        <p></p>
        {refresh_button}
      </div>
    );
  }
});

export default Transfers;
