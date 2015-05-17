import React from 'react';

function pretty_size(x) {
  if (x >= 1000000000) {
    return (x / 1000000000).toFixed(2) + 'G';
  } else if (x >= 1000000) {
    return (x / 1000000).toFixed(1) + 'M';
  } else if (x >= 1000) {
    return (x / 1000).toFixed(1) + 'K';
  } else {
    return x.toString();
  }
}

var ExecResult = React.createClass({
  render() {
    var result = this.props.result;
    if (result.type === 'error') {
      return (
        <Alert bsStyle='danger'>
          Error {result.message}
        </Alert>
      );
    }
    if (result.type === 'unrar') {
      var output = this.props.result.output.map((o) => {
        return <p>{o}</p>;
      });
      let progress = '';
      if (this.props.result.progress < 100) {
        progress = <ProgressBar min={0} now={this.props.result.progress} max={100}
                      label='%(percent)s%'/>;
      }
      return (
        <Alert bsStyle='success'>
          Unrar {result.src}
          {output}
          {progress}
        </Alert>
      );
    }
    var dst_size = pretty_size(result.dst_size);
    var src_size = pretty_size(result.src_size);
    var message = '';
    var arrow = '⇨';
    var style = 'info';
    let progress = <ProgressBar min={0} now={this.props.result.cur_size}
      max={this.props.result.src_size} label={pretty_size(this.props.result.cur_size)}/>;
    if (this.props.result.cur_size >= this.props.result.src_size) {
      progress = '';
    }
    if (result.type === 'overwrite') {
      message = `Overwrite dst (${dst_size}) < src (${src_size})`;
      style = 'warning';
    } else if (result.type === 'skip') {
      message = `Skip dst (${dst_size}) >= src (${src_size})`;
      arrow = '⇏';
      progress = '';
      style = 'warning';
    }
    return (
      <Alert bsStyle={style}>
        {message}<br />
        {result.src}<br/>
        {arrow}&nbsp;{result.dst}
        {progress}
      </Alert>
    );
  }
});

export default ExecResult;
