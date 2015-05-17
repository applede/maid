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
export var TransferredFile = React.createClass({
  render_copy_dest() {
    if (this.props.file.rule.action === 'copy') {
      return (
        <tr className='success'>
          <td colSpan={3}>
            ⇨&nbsp;{this.props.file.dest}
          </td>
        </tr>
      );
    }
    return null;
  },
  render() {
    var file = this.props.file;
    return (
      <tr>
        <tr className={result_class(file)}>
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
        {this.render_copy_dest()}
      </tr>
    );
  }
});

export default TransferredFile;
