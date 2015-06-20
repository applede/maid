import React from 'react';
import EditRule from './edit_rule.js';

// return tr class of result of the rule matching
function result_class(file) {
  if (file.rule) {
    if (file.rule.action === 'no match') {
      return 'danger';
    } else if (file.rule.action === 'unrar') {
      return 'success';
    }
  }
  return '';
}

// represents a file in a transfer
export var TransferredFiles = React.createClass({
  render() {
    var key = 1;
    var files = [];
    this.props.files.forEach(file => {
      files.push(
        <tr key={key++} className={result_class(file)}>
          <td>{file.name}</td>
          <td>{file.rule.action}</td>
          <td>
            <ModalTrigger modal={<EditRule file={file} refresh={this.props.refresh}/>}>
              <div className='right-float'>
                <span className='glyphicon glyphicon-edit clickable'></span>
              </div>
            </ModalTrigger>
          </td>
        </tr>
      );
      if (file.rule.action === 'copy') {
        files.push(
          <tr key={key++} className='success'>
            <td colSpan={3}>
              ⇨&nbsp;{file.dest}
            </td>
          </tr>
        );
      }
    });
    return (
      <tbody>
        {files}
      </tbody>
    );
  }
});

export default TransferredFiles;
