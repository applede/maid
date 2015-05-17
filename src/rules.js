import React from 'react';
import EditRule from './edit_rule';
import rule_db from './rule_db';

var Rules = React.createClass({
  getInitialState() {
    return { rules: [] };
  },
  componentDidMount() {
    this.refresh();
  },
  refresh() {
    rule_db.load((rules) => {
      this.setState({ rules: rules });
    });
  },
  delete_rule(rule) {
    rule_db.delete(rule, (err) => {
      this.refresh();
    });
  },
  render() {
    var rules = this.state.rules.map((rule) => {
      return (
        <tr>
          <td>{rule.order}</td>
          <td>{rule.pattern}</td>
          <td>{rule.ext}</td>
          <td>{rule.action}</td>
          <td>{rule.kind}</td>
          <td>
            <ModalTrigger modal={<EditRule file={{ folder: 'Test',
               name: 'test S01E01 blah.' + rule.ext,
               rule: rule }}
              refresh={this.refresh}/>}>
              <span className='glyphicon glyphicon-edit clickable'></span>
            </ModalTrigger>
                &nbsp;
            <span className='glyphicon glyphicon-trash clickable'
                  onClick={ () => { this.delete_rule(rule); } }></span>
          </td>
        </tr>
      );
    });
    return (
      <div className='container'>
        <Table striped>
          <thead>
            <tr>
              <th>Order</th>
              <th>Pattern</th>
              <th>Ext</th>
              <th>Action</th>
              <th>Kind</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {rules}
          </tbody>
        </Table>
      </div>
    );
  }
});

export default Rules;